import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";
import { authTables } from "@convex-dev/auth/server";

const applicationTables = {
  tables: defineTable({
    name: v.string(),
    maxPlayers: v.number(),
    minBet: v.number(),
    maxBet: v.number(),
    isActive: v.boolean(),
  }),

  games: defineTable({
    tableId: v.id("tables"),
    playerId: v.id("users"),
    playerCards: v.array(
      v.object({
        suit: v.string(),
        rank: v.string(),
        value: v.number(),
      }),
    ),
    dealerCards: v.array(
      v.object({
        suit: v.string(),
        rank: v.string(),
        value: v.number(),
      }),
    ),
    playerScore: v.number(),
    dealerScore: v.number(),
    bet: v.number(),
    chips: v.number(),
    gameState: v.string(), // "betting", "playing", "dealer", "finished"
    result: v.optional(v.string()), // "win", "lose", "push", "blackjack"
    canDoubleDown: v.boolean(),
    dealerHidden: v.boolean(),
  })
    .index("by_table", ["tableId"])
    .index("by_player", ["playerId"]),
};

const adminTables = {
  admins: defineTable({
    adminId: v.id("users"),
  }).index("by_player", ["adminId"]),
};
const pollState = {
  pollState: defineTable({
    lastCheckedBlock: v.number(),
  }),
};

export default defineSchema({
  ...pollState,
  ...authTables,
  ...applicationTables,
  ...adminTables,
});
