import Image from "next/image";
import { IMAGES } from "@/lib/constants";

type AppHeaderProps = {
  title: string;
};

export function AppHeader({ title }: AppHeaderProps) {
  return (
    <header className="fixed top-0 z-50 w-full bg-surface/80 pt-safe shadow-[0_1px_8px_rgba(0,0,0,0.04)] backdrop-blur-xl">
      <div className="flex h-16 items-center justify-between px-margin-mobile">
        <div className="flex items-center gap-unit">
          <Image
            src={IMAGES.logo}
            alt="FoundryMeet Logo"
            width={120}
            height={32}
            className="h-8 w-auto object-contain"
          />
          <span className="text-headline-sm font-semibold tracking-tight">
            {title}
          </span>
        </div>
        <Image
          src={IMAGES.profileAvatar}
          alt="Profile"
          width={32}
          height={32}
          className="h-8 w-8 rounded-full object-cover ring-2 ring-surface-container-high"
        />
      </div>
    </header>
  );
}
