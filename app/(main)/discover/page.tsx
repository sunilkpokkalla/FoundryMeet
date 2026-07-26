"use client";

import { useState } from "react";
import { AppHeader } from "@/components/app-header";
import { BottomNav } from "@/components/bottom-nav";
import { ProfileCard } from "@/components/profile-card";
import { Icon } from "@/components/icon";
import { DISCOVER_PROFILES } from "@/lib/constants";

const FILTERS = [
  { label: "Stage: Seed+", active: true, icon: "filter_list" },
  { label: "Goal: Fundraising", active: false },
  { label: "Industry: AI/ML", active: false },
  { label: "Location", active: false },
];

export default function DiscoverPage() {
  const [profiles, setProfiles] = useState(DISCOVER_PROFILES);

  function handleSkip(id: string) {
    setProfiles((current) => current.filter((profile) => profile.id !== id));
  }

  return (
    <>
      <AppHeader title="Discover" />
      <main className="relative min-h-screen bg-surface pt-16">
        <section className="flex flex-col gap-4 px-margin-mobile py-4">
          <div className="flex flex-col gap-1">
            <h1 className="text-headline-md font-semibold text-on-surface">
              Curated for you
            </h1>
            <p className="text-body-md text-on-surface-variant">
              High-signal matches based on your recent activity.
            </p>
          </div>

          <div className="no-scrollbar -mx-margin-mobile flex gap-2 overflow-x-auto px-margin-mobile pb-2">
            {FILTERS.map(({ label, active, icon }) => (
              <button
                key={label}
                type="button"
                className={`flex items-center gap-2 rounded-full px-4 py-2 whitespace-nowrap transition-transform active:scale-95 ${
                  active
                    ? "bg-secondary-container text-on-secondary-container"
                    : "bg-surface-container-high text-on-surface-variant"
                }`}
              >
                {icon && <Icon name={icon} className="text-[18px]" />}
                <span className="text-label-md">{label}</span>
              </button>
            ))}
          </div>
        </section>

        <div className="flex flex-col gap-6 px-margin-mobile">
          {profiles.map((profile) => (
            <ProfileCard
              key={profile.id}
              profile={profile}
              onSkip={handleSkip}
            />
          ))}

          <div className="flex flex-col items-center justify-center gap-4 rounded-2xl border-2 border-dashed border-outline-variant/30 bg-surface-container-low px-8 py-12 text-center">
            <div className="mb-2 flex h-16 w-16 items-center justify-center rounded-full bg-secondary-container">
              <Icon
                name="auto_awesome"
                className="text-3xl text-on-secondary-container"
              />
            </div>
            <h3 className="text-headline-sm font-semibold text-on-surface">
              That&apos;s all for today
            </h3>
            <p className="max-w-[280px] text-body-md text-on-surface-variant">
              We&apos;re busy hand-picking your next batch of high-signal
              matches. Check back tomorrow!
            </p>
            <button
              type="button"
              className="mt-2 rounded-full bg-secondary-fixed px-6 py-3 text-label-md text-on-secondary-fixed-variant transition-transform active:scale-95"
            >
              Refine My Preferences
            </button>
          </div>
        </div>
      </main>
      <BottomNav />
    </>
  );
}
