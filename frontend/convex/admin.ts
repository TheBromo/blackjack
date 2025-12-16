import { internalAction } from "./_generated/server";
import { internal } from "./_generated/api";
import { v } from "convex/values";

import { ethers } from "ethers";
import { BlackjackAbi__factory } from "../types/factories/BlackjackAbi__factory";

export const checkForPlayerJoinEvents = internalAction({
  args: {},
  handler: async (ctx) => {
    const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS;
    if (!CONTRACT_ADDRESS) {
      throw new Error("CONTRACT_ADDRESS environment variable is not set!");
    }
    const provider = new ethers.JsonRpcProvider();
    const contract = BlackjackAbi__factory.connect(CONTRACT_ADDRESS, provider);

    console.log("checking...");
    // const docs = await ctx.db.query("pollState").collect();
    // const state = docs[0];

    const lastChecked = await provider.getBlockNumber();

    const latestBlock = await provider.getBlockNumber();
    const eventFilter = contract.filters.PlayerJoined();
    const events = await contract.queryFilter(
      eventFilter,
      lastChecked,
      latestBlock,
    );

    for (const evt of events) {
      const blockNum = evt.blockNumber;
      await ctx.scheduler.runAfter(0, internal.admin.doSomething, {
        blockNumnber: blockNum,
      });
    }

    // await ctx.db.patch(state._id, {
    //   lastCheckedBlock: latestBlock,
    // });
  },
});

export const doSomething = internalAction({
  args: {
    blockNumnber: v.number(),
  },
  handler: () => {
    return "success";
  },
});
