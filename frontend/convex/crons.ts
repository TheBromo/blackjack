import { cronJobs } from "convex/server";
import { internal } from "./_generated/api";

const crons = cronJobs();

crons.interval(
  "check events",
  { seconds: 15 },
  internal.admin.checkForPlayerJoinEvents,
);

export default crons;
