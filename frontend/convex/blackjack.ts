import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { getAuthUserId } from "@convex-dev/auth/server";

// Card utilities
const suits = ["♠", "♥", "♦", "♣"];
const ranks = [
  "A",
  "2",
  "3",
  "4",
  "5",
  "6",
  "7",
  "8",
  "9",
  "10",
  "J",
  "Q",
  "K",
];

function createDeck() {
  const deck = [];
  for (const suit of suits) {
    for (const rank of ranks) {
      let value = parseInt(rank);
      if (rank === "A") value = 11;
      else if (["J", "Q", "K"].includes(rank)) value = 10;

      deck.push({ suit, rank, value });
    }
  }
  return shuffleDeck(deck);
}

function shuffleDeck(deck: any[]) {
  const shuffled = [...deck];
  for (let i = shuffled.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
  }
  return shuffled;
}

function calculateScore(cards: any[]) {
  let score = 0;
  let aces = 0;

  for (const card of cards) {
    if (card.rank === "A") {
      aces++;
      score += 11;
    } else {
      score += card.value;
    }
  }

  while (score > 21 && aces > 0) {
    score -= 10;
    aces--;
  }

  return score;
}

export const getTables = query({
  args: {},
  handler: async (ctx) => {
    const tables = await ctx.db
      .query("tables")
      .filter((q) => q.eq(q.field("isActive"), true))
      .collect();

    // Get player count for each table
    const tablesWithPlayers = await Promise.all(
      tables.map(async (table) => {
        const games = await ctx.db
          .query("games")
          .withIndex("by_table", (q) => q.eq("tableId", table._id))
          .filter((q) => q.neq(q.field("gameState"), "finished"))
          .collect();

        return {
          ...table,
          playerCount: games.length,
        };
      }),
    );

    return tablesWithPlayers;
  },
});

export const getCurrentGame = query({
  args: {},
  handler: async (ctx) => {
    const userId = await getAuthUserId(ctx);
    if (!userId) return null;

    const game = await ctx.db
      .query("games")
      .withIndex("by_player", (q) => q.eq("playerId", userId))
      .filter((q) => q.neq(q.field("gameState"), "finished"))
      .first();

    if (!game) return null;

    const table = await ctx.db.get(game.tableId);

    return {
      ...game,
      table,
    };
  },
});

export const joinTable = mutation({
  args: { tableId: v.id("tables") },
  handler: async (ctx, args) => {
    const userId = await getAuthUserId(ctx);
    if (!userId) throw new Error("Not authenticated");

    // Check if player already has an active game
    const existingGame = await ctx.db
      .query("games")
      .withIndex("by_player", (q) => q.eq("playerId", userId))
      .filter((q) => q.neq(q.field("gameState"), "finished"))
      .first();

    if (existingGame) {
      throw new Error("You already have an active game");
    }

    const table = await ctx.db.get(args.tableId);
    if (!table) throw new Error("Table not found");

    // Create new game
    const gameId = await ctx.db.insert("games", {
      tableId: args.tableId,
      playerId: userId,
      playerCards: [],
      dealerCards: [],
      playerScore: 0,
      dealerScore: 0,
      bet: 0,
      chips: 1000, // Starting chips
      gameState: "betting",
      canDoubleDown: false,
      dealerHidden: true,
    });

    return gameId;
  },
});

export const placeBet = mutation({
  args: { bet: v.number() },
  handler: async (ctx, args) => {
    const userId = await getAuthUserId(ctx);
    if (!userId) throw new Error("Not authenticated");

    const game = await ctx.db
      .query("games")
      .withIndex("by_player", (q) => q.eq("playerId", userId))
      .filter((q) => q.eq(q.field("gameState"), "betting"))
      .first();

    if (!game) throw new Error("No active betting game found");

    if (args.bet > game.chips) {
      throw new Error("Insufficient chips");
    }

    const table = await ctx.db.get(game.tableId);
    if (!table) throw new Error("Table not found");

    if (args.bet < table.minBet || args.bet > table.maxBet) {
      throw new Error(
        `Bet must be between ${table.minBet} and ${table.maxBet}`,
      );
    }

    // Deal initial cards
    const deck = createDeck();
    const playerCards = [deck[0], deck[2]];
    const dealerCards = [deck[1], deck[3]];

    const playerScore = calculateScore(playerCards);
    const dealerScore = calculateScore([dealerCards[0]]); // Only first card for display

    const isBlackjack = playerScore === 21;
    const canDoubleDown = !isBlackjack && playerCards.length === 2;

    await ctx.db.patch(game._id, {
      bet: args.bet,
      chips: game.chips - args.bet,
      playerCards,
      dealerCards,
      playerScore,
      dealerScore,
      gameState: isBlackjack ? "dealer" : "playing",
      canDoubleDown,
      dealerHidden: !isBlackjack,
    });

    if (isBlackjack) {
      // Auto-resolve blackjack
      const fullDealerScore = calculateScore(dealerCards);
      const dealerBlackjack = fullDealerScore === 21;

      let result: string;
      let winnings = 0;

      if (dealerBlackjack) {
        result = "push";
        winnings = args.bet; // Return bet
      } else {
        result = "blackjack";
        winnings = args.bet + Math.floor(args.bet * 1.5); // 3:2 payout
      }

      await ctx.db.patch(game._id, {
        gameState: "finished",
        result,
        chips: game.chips - args.bet + winnings,
        dealerScore: fullDealerScore,
        dealerHidden: false,
      });
    }
  },
});

export const hit = mutation({
  args: {},
  handler: async (ctx) => {
    const userId = await getAuthUserId(ctx);
    if (!userId) throw new Error("Not authenticated");

    const game = await ctx.db
      .query("games")
      .withIndex("by_player", (q) => q.eq("playerId", userId))
      .filter((q) => q.eq(q.field("gameState"), "playing"))
      .first();

    if (!game) throw new Error("No active game found");

    const deck = createDeck();
    const newCard = deck[0];
    const newPlayerCards = [...game.playerCards, newCard];
    const newPlayerScore = calculateScore(newPlayerCards);

    const isBust = newPlayerScore > 21;
    const canDoubleDown = false; // Can't double down after hitting

    await ctx.db.patch(game._id, {
      playerCards: newPlayerCards,
      playerScore: newPlayerScore,
      gameState: isBust ? "finished" : "playing",
      canDoubleDown,
      result: isBust ? "lose" : undefined,
    });
  },
});

export const stand = mutation({
  args: {},
  handler: async (ctx) => {
    const userId = await getAuthUserId(ctx);
    if (!userId) throw new Error("Not authenticated");

    const game = await ctx.db
      .query("games")
      .withIndex("by_player", (q) => q.eq("playerId", userId))
      .filter((q) => q.eq(q.field("gameState"), "playing"))
      .first();

    if (!game) throw new Error("No active game found");

    // Dealer plays
    const dealerCards = [...game.dealerCards];
    let dealerScore = calculateScore(dealerCards);

    const deck = createDeck();
    let deckIndex = 0;

    while (dealerScore < 17) {
      dealerCards.push(deck[deckIndex++]);
      dealerScore = calculateScore(dealerCards);
    }

    // Determine result
    let result: string;
    let winnings = 0;

    if (dealerScore > 21) {
      result = "win";
      winnings = game.bet * 2;
    } else if (game.playerScore > dealerScore) {
      result = "win";
      winnings = game.bet * 2;
    } else if (game.playerScore < dealerScore) {
      result = "lose";
      winnings = 0;
    } else {
      result = "push";
      winnings = game.bet;
    }

    await ctx.db.patch(game._id, {
      dealerCards,
      dealerScore,
      gameState: "finished",
      result,
      chips: game.chips + winnings,
      dealerHidden: false,
    });
  },
});

export const doubleDown = mutation({
  args: {},
  handler: async (ctx) => {
    const userId = await getAuthUserId(ctx);
    if (!userId) throw new Error("Not authenticated");

    const game = await ctx.db
      .query("games")
      .withIndex("by_player", (q) => q.eq("playerId", userId))
      .filter((q) => q.eq(q.field("gameState"), "playing"))
      .first();

    if (!game || !game.canDoubleDown) {
      throw new Error("Cannot double down");
    }

    if (game.chips < game.bet) {
      throw new Error("Insufficient chips to double down");
    }

    // Double the bet and take one card
    const deck = createDeck();
    const newCard = deck[0];
    const newPlayerCards = [...game.playerCards, newCard];
    const newPlayerScore = calculateScore(newPlayerCards);
    const newBet = game.bet * 2;

    if (newPlayerScore > 21) {
      // Bust
      await ctx.db.patch(game._id, {
        playerCards: newPlayerCards,
        playerScore: newPlayerScore,
        bet: newBet,
        chips: game.chips - game.bet,
        gameState: "finished",
        result: "lose",
        canDoubleDown: false,
      });
      return;
    }

    // Dealer plays
    const dealerCards = [...game.dealerCards];
    let dealerScore = calculateScore(dealerCards);

    let deckIndex = 1;
    while (dealerScore < 17) {
      dealerCards.push(deck[deckIndex++]);
      dealerScore = calculateScore(dealerCards);
    }

    // Determine result
    let result: string;
    let winnings = 0;

    if (dealerScore > 21) {
      result = "win";
      winnings = newBet * 2;
    } else if (newPlayerScore > dealerScore) {
      result = "win";
      winnings = newBet * 2;
    } else if (newPlayerScore < dealerScore) {
      result = "lose";
      winnings = 0;
    } else {
      result = "push";
      winnings = newBet;
    }

    await ctx.db.patch(game._id, {
      playerCards: newPlayerCards,
      dealerCards,
      playerScore: newPlayerScore,
      dealerScore,
      bet: newBet,
      chips: game.chips - game.bet + winnings,
      gameState: "finished",
      result,
      canDoubleDown: false,
      dealerHidden: false,
    });
  },
});

export const newGame = mutation({
  args: {},
  handler: async (ctx) => {
    const userId = await getAuthUserId(ctx);
    if (!userId) throw new Error("Not authenticated");

    const game = await ctx.db
      .query("games")
      .withIndex("by_player", (q) => q.eq("playerId", userId))
      .filter((q) => q.eq(q.field("gameState"), "finished"))
      .first();

    if (!game) throw new Error("No finished game found");

    if (game.chips <= 0) {
      // Reset chips if player is broke
      await ctx.db.patch(game._id, {
        chips: 1000,
      });
    }

    await ctx.db.patch(game._id, {
      playerCards: [],
      dealerCards: [],
      playerScore: 0,
      dealerScore: 0,
      bet: 0,
      gameState: "betting",
      result: undefined,
      canDoubleDown: false,
      dealerHidden: true,
    });
  },
});

export const leaveTable = mutation({
  args: {},
  handler: async (ctx) => {
    const userId = await getAuthUserId(ctx);
    if (!userId) throw new Error("Not authenticated");

    const game = await ctx.db
      .query("games")
      .withIndex("by_player", (q) => q.eq("playerId", userId))
      .filter((q) => q.neq(q.field("gameState"), "finished"))
      .first();

    if (game) {
      await ctx.db.delete(game._id);
    }
  },
});
