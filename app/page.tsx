"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

export default function HomePage() {
  const router = useRouter();

  useEffect(() => {
    router.replace("/onboarding/");
  }, [router]);

  return (
    <main className="flex min-h-screen items-center justify-center bg-surface">
      <p className="text-body-md text-on-surface-variant">Loading FoundryMeet...</p>
    </main>
  );
}
