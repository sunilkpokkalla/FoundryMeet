import type { CapacitorConfig } from "@capacitor/cli";

const config: CapacitorConfig = {
  appId: "com.foundrymeet.app",
  appName: "FoundryMeet",
  webDir: "out",
  ios: {
    contentInset: "automatic",
    scrollEnabled: true,
  },
  server: {
    iosScheme: "capacitor",
    androidScheme: "https",
  },
};

export default config;
