import { mutation } from "./_generated/server";

export const setupTables = mutation({
  args: {},
  handler: async (ctx) => {
    // Check if tables already exist
    const existingTables = await ctx.db.query("tables").collect();
    if (existingTables.length > 0) {
      return "Tables already exist";
    }

    // Create sample tables
    const tables = [
      {
        name: "Beginner Table",
        maxPlayers: 6,
        minBet: 10,
        maxBet: 100,
        isActive: true,
      },
      {
        name: "High Roller",
        maxPlayers: 4,
        minBet: 100,
        maxBet: 1000,
        isActive: true,
      },
      {
        name: "VIP Lounge",
        maxPlayers: 3,
        minBet: 500,
        maxBet: 5000,
        isActive: true,
      },
    ];

    for (const table of tables) {
      await ctx.db.insert("tables", table);
    }

    return "Tables created successfully";
  },
});
