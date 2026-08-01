import type { Metadata } from "next";
import "./globals.css";
import { Nav } from "@/components/Nav";

/*
  No next/font/google here, deliberately.

  The scaffold wires up Geist, which downloads and self-hosts the face at build
  time. That makes `next build` need network access — awkward for a build step in
  a Makefile, and it adds ~100KB to a static export that a Go binary ships. The
  system mono/sans pairing in globals.css is the right register for an operator's
  tool regardless, and it matches the identity the Go-served pages already had.
*/

export const metadata: Metadata = {
  title: "sonyliv-mock",
  description:
    "Load simulator and event stepper for the SonyLIV concurrency pipeline.",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" className="h-full">
      <body className="flex min-h-full flex-col">
        <Nav />
        <main className="mx-auto w-full max-w-[80rem] flex-1 px-5 pt-6 pb-16">
          {children}
        </main>
      </body>
    </html>
  );
}
