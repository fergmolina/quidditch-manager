// Lengths are counted in code points, like Postgres `char_length`, so what passes here also passes the table CHECK
// constraints (a message of emoji must not reach the database as a 500).
export const codePoints = (s: string): number => [...s].length;
