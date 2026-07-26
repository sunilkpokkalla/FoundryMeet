"use client";

import Image from "next/image";
import Link from "next/link";
import { AppHeader } from "@/components/app-header";
import { BottomNav } from "@/components/bottom-nav";
import { Icon } from "@/components/icon";
import { IMAGES } from "@/lib/constants";

const PROFILE_STATS = [
  { label: "Coffee Chats", value: "12" },
  { label: "Connections", value: "8" },
  { label: "Follow-ups", value: "3" },
];

const SKILLS = ["Product", "Growth", "AI/ML", "Fundraising"];

export default function ProfilePage() {
  return (
    <>
      <AppHeader title="Profile" />
      <main className="relative min-h-screen bg-surface pt-16">
        <div className="flex flex-col gap-6 px-margin-mobile py-6">
          <div className="flex flex-col items-center gap-4 text-center">
            <Image
              src={IMAGES.profileAvatar}
              alt="Your profile"
              width={96}
              height={96}
              className="h-24 w-24 rounded-full object-cover ring-4 ring-surface-container-high"
            />
            <div>
              <h1 className="text-headline-md font-semibold text-on-surface">
                Alex Morgan
              </h1>
              <p className="text-body-md text-on-surface-variant">
                Founder @ Stealth • San Francisco
              </p>
            </div>
            <span className="rounded-full bg-secondary-container px-4 py-1 text-label-sm text-on-secondary-container">
              Seed Stage
            </span>
          </div>

          <div className="grid grid-cols-3 gap-3">
            {PROFILE_STATS.map((stat) => (
              <div
                key={stat.label}
                className="rounded-xl bg-surface-container-lowest p-4 text-center shadow-sm"
              >
                <p className="text-headline-sm font-semibold text-on-surface">
                  {stat.value}
                </p>
                <p className="text-label-sm text-on-surface-variant">
                  {stat.label}
                </p>
              </div>
            ))}
          </div>

          <div className="rounded-xl bg-surface-container-lowest p-5 shadow-sm">
            <h2 className="mb-2 text-label-sm tracking-widest text-on-surface-variant uppercase">
              About
            </h2>
            <p className="text-body-md text-on-surface">
              Building the future of founder networking. Looking for early GTM
              partners and Series A insights from operators who&apos;ve scaled
              B2B SaaS.
            </p>
          </div>

          <div className="rounded-xl bg-surface-container-lowest p-5 shadow-sm">
            <h2 className="mb-3 text-label-sm tracking-widest text-on-surface-variant uppercase">
              Skills
            </h2>
            <div className="flex flex-wrap gap-2">
              {SKILLS.map((skill) => (
                <span
                  key={skill}
                  className="rounded-full bg-surface-container px-3 py-1 text-label-sm text-on-surface-variant"
                >
                  {skill}
                </span>
              ))}
            </div>
          </div>

          <div className="flex flex-col gap-3">
            <Link
              href="/onboarding"
              className="flex items-center justify-between rounded-xl bg-surface-container-low p-4 transition-transform active:scale-[0.98]"
            >
              <div className="flex items-center gap-3">
                <Icon name="tune" className="text-secondary" />
                <span className="text-label-md text-on-surface">
                  Edit Preferences
                </span>
              </div>
              <Icon name="chevron_right" className="text-outline-variant" />
            </Link>
            <button
              type="button"
              className="flex items-center justify-between rounded-xl bg-surface-container-low p-4 transition-transform active:scale-[0.98]"
            >
              <div className="flex items-center gap-3">
                <Icon name="calendar_month" className="text-secondary" />
                <span className="text-label-md text-on-surface">
                  Connected Calendars
                </span>
              </div>
              <Icon name="chevron_right" className="text-outline-variant" />
            </button>
            <button
              type="button"
              className="flex items-center justify-between rounded-xl bg-surface-container-low p-4 transition-transform active:scale-[0.98]"
            >
              <div className="flex items-center gap-3">
                <Icon name="notifications" className="text-secondary" />
                <span className="text-label-md text-on-surface">
                  Notifications
                </span>
              </div>
              <Icon name="chevron_right" className="text-outline-variant" />
            </button>
          </div>
        </div>
      </main>
      <BottomNav />
    </>
  );
}
