"use client";

import Image from "next/image";
import Link from "next/link";
import { useState } from "react";
import type { DiscoverProfile } from "@/lib/constants";
import { Icon } from "@/components/icon";

type ProfileCardProps = {
  profile: DiscoverProfile;
  onSkip: (id: string) => void;
};

export function ProfileCard({ profile, onSkip }: ProfileCardProps) {
  const [removing, setRemoving] = useState(false);

  function handleSkip() {
    setRemoving(true);
    window.setTimeout(() => onSkip(profile.id), 500);
  }

  return (
    <div
      className={`group relative overflow-hidden rounded-xl bg-surface-container-lowest shadow-[0_4px_20px_rgba(30,27,24,0.04)] transition-all duration-500 ease-in-out hover:shadow-[0_8px_30px_rgba(30,27,24,0.08)] ${
        removing
          ? "-translate-x-full -rotate-[5deg] opacity-0"
          : "translate-x-0 rotate-0 opacity-100"
      }`}
    >
      <div className="relative h-48 w-full overflow-hidden">
        <Image
          src={profile.image}
          alt={profile.name}
          fill
          className="object-cover"
          sizes="(max-width: 768px) 100vw, 600px"
        />
        <div className="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent" />
        <div className="absolute right-6 bottom-4 left-6 flex items-end justify-between">
          <div className="flex flex-col text-white">
            <h2 className="text-headline-sm font-semibold">{profile.name}</h2>
            <p className="text-body-md opacity-90">{profile.title}</p>
          </div>
          {profile.active && (
            <div className="flex items-center gap-1 rounded-full bg-tertiary/20 px-3 py-1 backdrop-blur-md">
              <div className="h-2 w-2 animate-pulse rounded-full bg-on-tertiary-container" />
              <span className="text-label-sm text-white">Active</span>
            </div>
          )}
        </div>
      </div>

      <div className="flex flex-col gap-5 p-6">
        <div className="flex flex-col gap-3">
          <span className="text-label-sm tracking-wider text-on-surface-variant uppercase">
            Top Expertise
          </span>
          <div className="flex flex-wrap gap-2">
            {profile.expertise.map((skill) => (
              <span
                key={skill}
                className="rounded-full bg-surface-container px-3 py-1 text-label-sm text-on-surface-variant"
              >
                {skill}
              </span>
            ))}
          </div>
        </div>

        <div className="flex flex-col gap-2 rounded-lg bg-surface-container-low p-4">
          <span className="text-label-sm tracking-wider text-on-secondary-fixed-variant uppercase">
            Looking for
          </span>
          <p className="text-body-md text-on-surface">{profile.lookingFor}</p>
        </div>

        <div className="mt-2 flex items-center gap-3">
          <Link
            href="/schedule"
            className="flex flex-1 items-center justify-center gap-2 rounded-xl bg-primary py-4 text-label-md text-on-primary transition-transform active:scale-[0.98]"
          >
            <Icon name="coffee" className="text-[20px]" />
            Request Coffee Chat
          </Link>
          <button
            type="button"
            onClick={handleSkip}
            className="flex h-14 w-14 items-center justify-center rounded-xl bg-surface-container-high text-on-surface transition-colors active:bg-error-container active:text-on-error-container"
            aria-label={`Skip ${profile.name}`}
          >
            <Icon name="close" />
          </button>
        </div>
      </div>
    </div>
  );
}
