import type { Metadata } from "next";
import "./globals.css";
import { GlobalTabBar } from "@/components/layout/global-tab-bar";

export const metadata: Metadata = {
  title: "3D Marketplace",
  description: "AR-powered 3D product marketplace",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="ko">
      <body className="min-h-screen flex flex-col">
        <main className="flex-1">{children}</main>
        <GlobalTabBar />
      </body>
    </html>
  );
}
