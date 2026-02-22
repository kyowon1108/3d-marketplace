// [FREEZE] — Gate 0 locked
"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const tabs = [
  { href: "/", label: "Home" },
  { href: "/products", label: "Browse" },
  { href: "/app/sell/new", label: "Sell" },
  { href: "/app/inbox", label: "Inbox" },
  { href: "/app/profile", label: "Profile" },
] as const;

export function GlobalTabBar() {
  const pathname = usePathname();

  return (
    <nav className="sticky bottom-0 border-t border-gray-200 bg-white">
      <div className="flex justify-around">
        {tabs.map((tab) => {
          const active =
            tab.href === "/"
              ? pathname === "/"
              : pathname.startsWith(tab.href);
          return (
            <Link
              key={tab.href}
              href={tab.href}
              className={`flex-1 py-3 text-center text-xs font-medium transition-colors ${
                active ? "text-brand-600" : "text-gray-500 hover:text-gray-700"
              }`}
            >
              {tab.label}
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
