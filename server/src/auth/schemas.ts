import { z } from "zod";
import { isAllowedNext } from "../http/redirect.js";

export const emailSchema = z.string().trim().toLowerCase().min(3).max(254).pipe(z.email());

export const nextPathSchema = z
  .string()
  .max(512)
  .refine((v) => isAllowedNext(v), "next");

export const magicFormSchema = z.object({
  email: emailSchema,
  next: z.string().max(512).optional(),
  lang: z.string().max(10).optional(),
});

export const verifyFormSchema = z.object({ token: z.string().max(128) });
