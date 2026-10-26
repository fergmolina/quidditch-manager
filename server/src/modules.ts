import type { Hono } from "hono";
import { registerAdminRoutes } from "./routes/admin.js";
import { registerFeedbackRoutes } from "./routes/feedback.js";
import { registerProfileRoutes } from "./routes/profile.js";
import type { AppEnv } from "./types.js";
import { registerLegalRoutes } from "./pages/legal.js";

export type RouteModule = (app: Hono<AppEnv>) => void;

export const MODULES: RouteModule[] = [
  registerProfileRoutes,
  registerLegalRoutes,
  registerFeedbackRoutes,
  registerAdminRoutes,
];
