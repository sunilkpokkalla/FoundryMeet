"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { NAV_ITEMS } from "@/lib/constants";
import { Icon } from "@/components/icon";

export function BottomNav() {
  const pathname = usePathname();

  return (
    <nav className="fixed bottom-0 z-50 w-full bg-surface/80 pb-safe shadow-[0_-1px_8px_rgba(0,0,0,0.04)] backdrop-blur-xl">
      <div className="flex h-16 items-center justify-around">
        {NAV_ITEMS.map(({ href, icon, label }) => {
          const active = pathname === href || pathname.startsWith(`${href}/`);

          return (
            <Link
              key={href}
              href={href}
              aria-current={active ? "page" : undefined}
              className={`flex min-w-[64px] flex-col items-center justify-center gap-1 transition-colors ${
                active
                  ? "font-semibold text-primary"
                  : "text-on-surface-variant hover:text-on-surface"
              }`}
            >
              <Icon name={icon} />
              <span className="text-label-sm">{label}</span>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
