"use client";

import Image from "next/image";
import Link from "next/link";
import { useState } from "react";
import { AppHeader } from "@/components/app-header";
import { BottomNav } from "@/components/bottom-nav";
import { Icon } from "@/components/icon";
import { UPCOMING_MATCHES } from "@/lib/constants";

type Tab = "upcoming" | "past";

export default function MatchesPage() {
  const [tab, setTab] = useState<Tab>("upcoming");

  return (
    <>
      <AppHeader title="Matches" />
      <main className="relative min-h-screen bg-surface pt-16">
        <div className="flex flex-col gap-4 px-margin-mobile py-unit">
          <div className="flex items-center justify-between">
            <h1 className="text-headline-md font-semibold text-on-surface">
              Connections
            </h1>
            <button
              type="button"
              className="flex items-center gap-1 text-label-md text-secondary"
            >
              <Icon name="filter_list" className="text-[20px]" />
              Filter
            </button>
          </div>

          <div className="flex rounded-xl bg-surface-container-low p-1">
            {(["upcoming", "past"] as const).map((value) => (
              <button
                key={value}
                type="button"
                onClick={() => setTab(value)}
                className={`flex-1 rounded-lg py-2 text-label-md transition-all ${
                  tab === value
                    ? "bg-surface-container-lowest text-on-surface shadow-sm"
                    : "text-on-surface-variant"
                }`}
              >
                {value === "upcoming" ? "Upcoming" : "Past Meets"}
              </button>
            ))}
          </div>
        </div>

        <div className="px-margin-mobile">
          {tab === "upcoming" ? (
            <div className="flex flex-col gap-4">
              {UPCOMING_MATCHES.map((match) => (
                <Link
                  key={match.id}
                  href="/schedule"
                  className={`group flex items-center gap-4 rounded-xl bg-surface-container-lowest p-4 shadow-sm transition-transform active:scale-[0.98] ${
                    match.highlighted ? "" : "opacity-80"
                  }`}
                >
                  <div className="relative">
                    <Image
                      src={match.image}
                      alt={match.name}
                      width={56}
                      height={56}
                      className="h-14 w-14 rounded-full object-cover"
                    />
                    <div className="absolute -right-1 -bottom-1 flex h-5 w-5 items-center justify-center rounded-full bg-tertiary-container">
                      <Icon
                        name="calendar_today"
                        className="filled text-[12px] text-on-tertiary-container"
                      />
                    </div>
                  </div>
                  <div className="min-w-0 flex-1">
                    <p
                      className={`text-label-sm tracking-wider uppercase ${
                        match.highlighted
                          ? "text-secondary"
                          : "text-on-surface-variant"
                      }`}
                    >
                      {match.time}
                    </p>
                    <h3 className="truncate text-headline-sm font-semibold text-on-surface">
                      {match.name}
                    </h3>
                    <p className="truncate text-body-md text-on-surface-variant">
                      {match.subtitle}
                    </p>
                  </div>
                  <Icon name="chevron_right" className="text-outline-variant" />
                </Link>
              ))}
            </div>
          ) : (
            <div className="flex flex-col gap-6">
              <div className="overflow-hidden rounded-xl bg-surface-container-lowest shadow-md">
                <div className="bg-gradient-to-br from-surface-container-low to-transparent p-6">
                  <div className="mb-4 flex items-start justify-between">
                    <div className="flex items-center gap-3">
                      <Image
                        src="https://lh3.googleusercontent.com/aida-public/AB6AXuC5UpyCIwxf-22iX3oCeDJKTlGRicpLCXLVHWfh96B1q4v8ix9MQiNmhCzfJPhBhRmGCzCPBg_rRWaHKfLVytPWGF1WnJWYshQajAU6k8znCwUgght7WFsjGjvOZ_pc5T4REKupB0uDQ0kARtiyClUhb01pUnwCNfr4wPJfiFayn3ms6FaZwjkYViQlItvYIuGh_MGDcR2WQV-5aG6ysU4oPdf3gbXLJ2jNpq5x5U-MrRXseVZogS53-Kdv-fm34kqqwzXb91Hbyvw"
                        alt="Elena Rodriguez"
                        width={48}
                        height={48}
                        className="h-12 w-12 rounded-full object-cover"
                      />
                      <div>
                        <h3 className="text-headline-sm font-semibold text-on-surface">
                          Elena Rodriguez
                        </h3>
                        <p className="text-label-sm text-on-surface-variant">
                          Met on Oct 12, 2023
                        </p>
                      </div>
                    </div>
                    <button
                      type="button"
                      className="rounded-full bg-surface-container-high p-2 text-on-surface-variant"
                    >
                      <Icon name="more_vert" className="text-[20px]" />
                    </button>
                  </div>
                  <label className="flex cursor-pointer items-center gap-3 rounded-lg bg-surface-container-lowest p-3 transition-colors active:bg-secondary-container/20">
                    <input
                      type="checkbox"
                      defaultChecked
                      className="h-5 w-5 rounded border-outline-variant accent-secondary"
                    />
                    <span className="text-label-md text-on-surface">
                      Successful Connection?
                    </span>
                    <Icon
                      name="stars"
                      filled
                      className="ml-auto text-secondary"
                    />
                  </label>
                </div>

                <div className="flex flex-col gap-6 p-6">
                  <div className="space-y-2">
                    <div className="flex items-center gap-2 text-on-surface-variant">
                      <Icon name="description" className="text-[18px]" />
                      <h4 className="text-label-sm tracking-widest uppercase">
                        Follow-up Notes
                      </h4>
                    </div>
                    <textarea
                      defaultValue="Discussed the Q1 roadmap for their LATAM expansion. Elena is looking for introductions to logistics partners in Mexico City. Highly impressed by their retention cohorts."
                      rows={3}
                      className="w-full resize-none border-none bg-transparent p-0 text-body-md leading-relaxed text-on-surface focus:ring-0"
                    />
                  </div>

                  <div className="grid grid-cols-1 gap-4">
                    <div className="space-y-3 rounded-xl bg-surface-container-low p-4">
                      <div className="flex items-center gap-2 text-on-surface-variant">
                        <Icon name="checklist" className="text-[18px]" />
                        <h4 className="text-label-sm tracking-widest uppercase">
                          Next Steps
                        </h4>
                      </div>
                      <ul className="space-y-2">
                        <li className="flex items-start gap-2">
                          <Icon
                            name="radio_button_unchecked"
                            className="text-[18px] text-secondary"
                          />
                          <span className="text-body-md text-on-surface">
                            Intro to Carlos regarding MEX supply chain
                          </span>
                        </li>
                        <li className="flex items-start gap-2">
                          <Icon
                            name="radio_button_unchecked"
                            className="text-[18px] text-secondary"
                          />
                          <span className="text-body-md text-on-surface">
                            Share the internal deck on user growth
                          </span>
                        </li>
                      </ul>
                      <button
                        type="button"
                        className="mt-2 flex items-center gap-1 text-label-sm text-secondary"
                      >
                        <Icon name="add" className="text-[18px]" />
                        Add Action Item
                      </button>
                    </div>

                    <div className="space-y-2 rounded-xl bg-surface-container-low p-4">
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-2 text-on-surface-variant">
                          <Icon
                            name="notifications_active"
                            className="text-[18px]"
                          />
                          <h4 className="text-label-sm tracking-widest uppercase">
                            Reminders
                          </h4>
                        </div>
                        <span className="text-label-sm text-secondary">
                          Set New
                        </span>
                      </div>
                      <div className="flex items-center gap-2 rounded-lg bg-surface-container-lowest p-2">
                        <span className="text-body-md text-on-surface">
                          Check in after board meeting
                        </span>
                        <span className="ml-auto text-label-sm text-on-surface-variant">
                          Oct 20
                        </span>
                      </div>
                    </div>
                  </div>

                  <div className="flex flex-col gap-3 pt-2">
                    <Link
                      href="/schedule"
                      className="flex w-full items-center justify-center gap-2 rounded-xl bg-primary py-3 text-label-md text-on-primary transition-transform active:scale-[0.99]"
                    >
                      <Icon name="calendar_add_on" className="text-[20px]" />
                      Schedule Follow-up
                    </Link>
                    <button
                      type="button"
                      className="flex w-full items-center justify-center gap-2 rounded-xl bg-surface-container-high py-3 text-label-md text-error transition-transform active:scale-[0.99]"
                    >
                      <Icon name="report" className="text-[20px]" />
                      Report or Block
                    </button>
                  </div>
                </div>
              </div>

              <div className="space-y-4 pb-8">
                <h4 className="px-1 text-label-sm tracking-widest text-on-surface-variant uppercase">
                  Earlier This Month
                </h4>
                <div className="divide-y divide-outline-variant/10">
                  <div className="flex items-center gap-4 py-4">
                    <Image
                      src="https://lh3.googleusercontent.com/aida-public/AB6AXuCwYZ3r0Tu8V7xeEjyqYxe06-8qF0PcIofaWfnsRVnA5rFMqYfjC7InhJXkZZcsOzx7kUMqR3NEHjHf7bQlpnjgqb2kZXMI78UNoV_3Ay9hRSlYxqOJZEEkmb-7soVH923LkHU1Cv580fg4L11CGSD1pc5QihBcnKgJvKj1XdaK3t1eMLJDfSaldgJFS2gZ2oGKonR42_YZwGlXtvMlXl_g5b4e2uLliRs1QDzwQV9XR_mo0h4KevDkzEGZ15jrU43mUvANlpEWgLA"
                      alt="David Wu"
                      width={40}
                      height={40}
                      className="h-10 w-10 rounded-full object-cover"
                    />
                    <div className="min-w-0 flex-1">
                      <h5 className="text-label-md text-on-surface">
                        David Wu
                      </h5>
                      <p className="text-label-sm text-on-surface-variant">
                        Oct 5 • 15 min intro
                      </p>
                    </div>
                    <Icon name="edit_note" className="text-outline-variant" />
                  </div>
                  <div className="flex items-center gap-4 py-4">
                    <Image
                      src="https://lh3.googleusercontent.com/aida-public/AB6AXuDAX_6ut7uxdC_4pWwKNIhf8iOAwDe3pEH33L3attn1u-XO43as3EoX9ym86B7TpZPVV81rfEdmuc0KP8iZN-_8Y9l4b6rmyiwwo79vW5ymj4Bnbh1Vh3gnO-JIFFki0AgCaMMTj-YJ8GfwyRosdPhBzXEnbNT3khsvMk7Mnh-mCzrlY2B7Ra-bybjH5yzbK7-Xklo4oA665g1zpP5K2Z8zmmbHBnOap6hfwPRvWcALAt5BNd6pZ-hDYwiDyF56earY0hZ0GJfmSg8"
                      alt="Sasha K."
                      width={40}
                      height={40}
                      className="h-10 w-10 rounded-full object-cover"
                    />
                    <div className="min-w-0 flex-1">
                      <h5 className="text-label-md text-on-surface">
                        Sasha K.
                      </h5>
                      <p className="text-label-sm text-on-surface-variant">
                        Oct 2 • Coffee meet
                      </p>
                    </div>
                    <Icon
                      name="check_circle"
                      filled
                      className="text-secondary"
                    />
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>
      </main>
      <BottomNav />
    </>
  );
}
