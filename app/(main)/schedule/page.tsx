"use client";

import Image from "next/image";
import { useState } from "react";
import { AppHeader } from "@/components/app-header";
import { BottomNav } from "@/components/bottom-nav";
import { Icon } from "@/components/icon";
import { IMAGES, SCHEDULE_DAYS, SCHEDULE_TIMES } from "@/lib/constants";

type LocationType = "in-person" | "virtual" | "office";

export default function SchedulePage() {
  const [selectedDay, setSelectedDay] = useState(0);
  const [selectedTime, setSelectedTime] = useState<number | null>(null);
  const [location, setLocation] = useState<LocationType>("in-person");
  const [locationPulse, setLocationPulse] = useState(false);

  function handleLocationChange(next: LocationType) {
    setLocation(next);
    setLocationPulse(true);
    window.setTimeout(() => setLocationPulse(false), 300);
  }

  return (
    <>
      <AppHeader title="Schedule" />
      <main className="relative min-h-screen bg-surface pt-16">
        <div className="flex w-full flex-col gap-6 px-margin-mobile">
          <div className="flex flex-col gap-2">
            <div className="flex items-center gap-3">
              <div className="relative">
                <Image
                  src="https://lh3.googleusercontent.com/aida-public/AB6AXuDdm7gAdasZdF-dakP4wehoS_9sc4j54elX-BxKAkXr2HtRngRgNwcD_HlIpmOQhFQPZORNr-UQcYMJ5wMuLPI7x1zYUpR2ZH06pPDhK2AnGLwhJ3oYIjAZ64G1Obolyaot9KW4UXyReLXcmTneMnp2OatftTwOTitflBavM7nqNyexnLRGFIoPiK53Eyf_OeTNQjAboeYeoHc6FSrlgDvQ7x4haLB-vgQwQnWCGTAi01I7_Ysq0lcJrXbvKNTQeCVpVAnvXpLi4uU"
                  alt="Sarah Chen"
                  width={56}
                  height={56}
                  className="h-14 w-14 rounded-full object-cover ring-2 ring-surface-container-high"
                />
                <div className="absolute right-0 bottom-0 flex h-4 w-4 items-center justify-center rounded-full border-2 border-surface bg-secondary">
                  <Icon name="check" className="text-[10px] text-on-secondary" />
                </div>
              </div>
              <div className="flex flex-col">
                <span className="text-label-sm tracking-wider text-secondary uppercase">
                  Accepted Match
                </span>
                <h1 className="text-headline-md font-semibold text-on-surface">
                  Coffee with Sarah
                </h1>
              </div>
            </div>
            <p className="text-body-md leading-relaxed text-on-surface-variant">
              You both have 3 overlapping gaps this week. Let&apos;s find a time
              that feels effortless.
            </p>
          </div>

          <div className="no-scrollbar -mx-margin-mobile flex gap-2 overflow-x-auto px-margin-mobile pb-2">
            {SCHEDULE_DAYS.map((day, index) => (
              <button
                key={day.day}
                type="button"
                onClick={() => setSelectedDay(index)}
                className={`flex-shrink-0 rounded-xl px-5 py-3 transition-all ${
                  selectedDay === index
                    ? "bg-primary text-on-primary shadow-md"
                    : "bg-surface-container-high text-on-surface-variant"
                }`}
              >
                <span className="block text-label-sm opacity-70">{day.label}</span>
                <span className="text-headline-sm font-semibold">{day.day}</span>
              </button>
            ))}
          </div>

          <div className="flex flex-col gap-4">
            <div className="flex items-center justify-between">
              <h2 className="text-label-md tracking-widest text-on-surface-variant uppercase">
                Suggested Slots
              </h2>
              <span className="rounded-full bg-secondary/10 px-2 py-0.5 text-[10px] text-secondary-fixed-dim">
                Shared Free Time
              </span>
            </div>
            <div className="grid grid-cols-2 gap-3">
              {SCHEDULE_TIMES.map((slot, index) => (
                <button
                  key={slot.time}
                  type="button"
                  onClick={() => setSelectedTime(index)}
                  className={`group relative flex flex-col rounded-xl p-4 shadow-sm transition-all active:scale-95 ${
                    selectedTime === index
                      ? "bg-secondary-container ring-2 ring-secondary"
                      : "bg-surface-container-low hover:bg-surface-container-high"
                  }`}
                >
                  <span className="text-label-sm text-on-surface-variant">
                    {slot.period}
                  </span>
                  <span className="text-headline-sm font-semibold text-on-surface">
                    {slot.time}
                  </span>
                  <div
                    className={`absolute top-3 right-3 transition-opacity ${
                      selectedTime === index ? "opacity-100" : "opacity-0"
                    }`}
                  >
                    <Icon name="check_circle" className="text-secondary" />
                  </div>
                </button>
              ))}
              <button
                type="button"
                className="flex flex-col items-center justify-center rounded-xl border-2 border-dashed border-outline-variant bg-surface-container-lowest p-4 transition-all hover:bg-surface-container-low"
              >
                <Icon name="more_time" className="text-on-surface-variant" />
                <span className="text-label-sm text-on-surface-variant">
                  Custom
                </span>
              </button>
            </div>
          </div>

          <div className="flex flex-col gap-4">
            <h2 className="text-label-md tracking-widest text-on-surface-variant uppercase">
              The Setting
            </h2>
            <div className="flex gap-1 rounded-2xl bg-surface-container-lowest p-2 shadow-sm">
              {(
                [
                  { id: "in-person", icon: "coffee", label: "In Person" },
                  { id: "virtual", icon: "videocam", label: "Virtual" },
                  { id: "office", icon: "apartment", label: "Office" },
                ] as const
              ).map((option) => (
                <button
                  key={option.id}
                  type="button"
                  onClick={() => handleLocationChange(option.id)}
                  className={`flex flex-1 flex-col items-center gap-1 rounded-xl py-3 transition-all ${
                    location === option.id
                      ? "bg-secondary-container text-on-secondary-container"
                      : "text-on-surface-variant"
                  }`}
                >
                  <Icon name={option.icon} />
                  <span className="text-label-sm">{option.label}</span>
                </button>
              ))}
            </div>

            {location === "in-person" && (
              <div
                className={`flex items-center gap-4 rounded-xl bg-surface-container-high p-4 transition-opacity duration-300 ${
                  locationPulse ? "opacity-0" : "opacity-100"
                }`}
              >
                <div
                  className="h-12 w-12 rounded-lg bg-cover bg-center"
                  style={{ backgroundImage: `url('${IMAGES.coffeeShop}')` }}
                />
                <div className="flex flex-1 flex-col">
                  <span className="text-label-md font-semibold text-on-surface">
                    The Foundry Lab (Chelsea)
                  </span>
                  <span className="text-label-sm text-on-surface-variant">
                    Sarah&apos;s favorite spot. 0.4 miles away.
                  </span>
                </div>
                <Icon name="chevron_right" className="text-on-surface-variant" />
              </div>
            )}
          </div>

          <div className="flex flex-col gap-4">
            <h2 className="text-label-md tracking-widest text-on-surface-variant uppercase">
              Meeting Intent
            </h2>
            <div className="space-y-4 rounded-2xl bg-surface-container-lowest p-5 shadow-sm">
              <div className="flex items-start gap-3">
                <div className="rounded-lg bg-on-tertiary-fixed-variant/10 p-2">
                  <Icon
                    name="lightbulb"
                    className="text-[20px] text-on-tertiary-fixed-variant"
                  />
                </div>
                <div className="flex flex-col">
                  <span className="text-label-md font-semibold text-on-surface">
                    Sarah wants to discuss:
                  </span>
                  <p className="mt-1 text-body-md text-on-surface-variant italic">
                    &quot;Seed-round roadmapping and hiring for early-stage product
                    teams.&quot;
                  </p>
                </div>
              </div>
              <div className="h-px bg-outline-variant/30" />
              <div className="flex flex-col gap-2">
                <label className="text-label-sm text-on-surface-variant">
                  Add your talking points (optional)
                </label>
                <textarea
                  placeholder="e.g. Scaling GTM strategies..."
                  rows={2}
                  className="w-full resize-none rounded-xl border-none bg-surface-container-low p-4 text-body-md outline-none transition-all focus:ring-1 focus:ring-secondary"
                />
              </div>
            </div>
          </div>

          <div className="flex flex-col gap-3 py-4">
            <button
              type="button"
              className="flex w-full items-center justify-center gap-2 rounded-full bg-primary py-4 text-headline-sm font-semibold text-on-primary shadow-xl transition-all hover:brightness-110 active:scale-[0.98]"
            >
              Confirm Chat
              <Icon name="send" />
            </button>
            <p className="px-8 text-center text-label-sm text-on-surface-variant">
              Confirming will send a calendar invite to both your synced emails.
            </p>
          </div>
        </div>
      </main>
      <BottomNav />
    </>
  );
}
