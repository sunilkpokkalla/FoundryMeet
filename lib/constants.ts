export const IMAGES = {
  logo: "https://lh3.googleusercontent.com/aida-public/AB6AXuAtGamAlnk8JM4wXMgbXItX7RZLIEsRgwTtUIiYaW9QNH7zUcxa9cyHhtAkzJOGUBtSoQHEtazJyKQopLjYxzGUTkLwnTkT3GF3aRIxQOd67l4XqimDmRjaA4sk6z54RtUfzeVAnzvW0YADlgjDFqMGhsT1T18jW0C5VLkgKII7O7tX3HwBWA5KdkeVOfDlApVz5Q0zesFRQjXwmJ2WRKaYCI490rSr61jeWUzNQ_UVDKl6SRhnnm7GwK8-sg0kDEdPJPyvWrDvP9w",
  profileAvatar:
    "https://lh3.googleusercontent.com/aida-public/AB6AXuBLzFzMJqHWTWqMWcsPamWeDvsBgaPv32aty5dT3-CgRuQQQgwRUxeUvTTiu4t9YErJSW5Q2kA1L2dBbMJDn2TEJGSnD9qjYSfuRsoW050gi8Oy_-E4x6xPTKn8G-LTGNOi3dX63eNBj0KtF0byUB2BsXEkpXE6LNeYh4QiBKBLupwBVVQgp_wF3gn0v9aDf8IS3NUH10SXosVkN8A5PjUhtX5NN46f2iPAxFvOzgq_B8Os_USlalP5icHfTk_aY2td-GXXXUPD1jQ",
  coffeeShop:
    "https://lh3.googleusercontent.com/aida-public/AB6AXuBgKW8IRrnd1uRaSrpNOw27IID3d8NMA0eus6Z5SfcpeBHoraRYGf3lN89oBzLccYXmx4JGO_4_M6qtL4FL7lyuTUeAkFTGqlmY8UUB1-JlafeDeKafayOX9UdnT7xBPj4J-KWsbECy2OsBWwsEmNLo3F2B8WSdh4TmX0gChMoG-OeAoM9wgAjg-Bp81y6zszjUiRZwVIBKYgk9_8ryXeybMRkTLg1pHPAUZS7ussFNOg38xPmt8ifSlPlQyGu1iHjegi30iF-RlI4",
} as const;

export type DiscoverProfile = {
  id: string;
  name: string;
  title: string;
  image: string;
  active?: boolean;
  expertise: string[];
  lookingFor: string;
};

export const DISCOVER_PROFILES: DiscoverProfile[] = [
  {
    id: "sarah-chen",
    name: "Sarah Chen",
    title: "CTO @ Stealth AI",
    image:
      "https://lh3.googleusercontent.com/aida-public/AB6AXuA0QfBeBm1DioWiMlUSwaNwhkst_KPXGv2hscKZ2WCivesiC-ZRg8rn7JQFo1RjP_A9hbX26eOk7mEfxWofkPWxOji9sb8uLBOhotCKhc_rSfmXtqMhdrSxgVJkINqhpUT9dEYXN4r0iSz6ThAj72IKacQNHzUg_n-QsoKhhmFdFyhnKE7cZpOmD1WXAkKByP6UttP7z8BFt6BBTIyvpa3qmuB8_C4BY3BCoDvveSHfXMKYefVvbZfp1D-kqG0sq5xTW4JT0Z2QsNg",
    active: true,
    expertise: [
      "Natural Language Processing",
      "Cloud Infrastructure",
      "Scaling Teams",
    ],
    lookingFor:
      "Potential GTM partners and Series A insights from founders who've scaled to $10M ARR.",
  },
  {
    id: "marcus-aris",
    name: "Marcus Aris",
    title: "CEO @ Bloom Logistics",
    image:
      "https://lh3.googleusercontent.com/aida-public/AB6AXuBCtE5qu2rf2QU80DNGHCzWZ-AUgsifbN4BMvaOdZSLRFmeki7ZYM0JROldW9HKvoS1GPaoFUTwgYmTrDBWCv716Stg_0q8kl7EyI8MhjlzzOrxQ8a8YUfsbdkTeXDPhTD5bxusQN7mQcm0gZAkKIfP4bntsMxF21ixvM_CUU_ipbTMtXy4I87Bo78BUGpmJnKMPrBmIHjd-JDVgqIqJ2unLKKdSOkIfBbjbzaW216WKUxWJPBT24Vvgddbap3hKPkPMOBY9rQJo7U",
    expertise: ["Operations", "Supply Chain AI", "Series B Prep"],
    lookingFor:
      "Mentoring early-stage founders in the logistics space and exploring sustainable packaging tech.",
  },
];

export const UPCOMING_MATCHES = [
  {
    id: "sarah-chen",
    name: "Sarah Chen",
    subtitle: "Series A • Fintech Strategy",
    time: "Tomorrow, 10:00 AM",
    highlighted: true,
    image:
      "https://lh3.googleusercontent.com/aida-public/AB6AXuAnGmUMP5OLQFnSTLG8AsQBJPZ29bPgI5rPnf32Jf4CgFQGBsanjWBMzRE2MfNgWqT6HNa9KwWZVwQD4PpL7AD-xhhKQfACnowuS01N1T3L_qrWgwBqusvEIK0Xx8mLWl3h0jOzv7MeC35ZQ0VnwN3TgmIHfKX9q4T0JiYEjhd-YpstnEifi5yKH8CQ6RRuHvMrU0ED7gHLRBdlXxjOcc-L77ojbyRBv6NRjvyx2NT414tOcFoFh7mIogvmhpMY0SlgpKirWxL0uZs",
  },
  {
    id: "marcus-thorne",
    name: "Marcus Thorne",
    subtitle: "Foundry Partners • Seed Stage",
    time: "Oct 24, 2:30 PM",
    highlighted: false,
    image:
      "https://lh3.googleusercontent.com/aida-public/AB6AXuCyIPR-cKgU4WKeZGMRUO9OEV-zmBlBvawOnCu9RS5Vx75PG33flHxX-Fika8gqJ8giVl96xSX6LMfucV5fJp6qFRC8_0X7IPOb5lPRKFy7GSIg7vKw1KRDmZ1XjpcPxoT8SfFtGVhtXfedQ_R8YwgDVTCjv6MTmHjcvaeYtMP_T0bHL9rrJzQgWMEFp7JdJVq2tg5uextc8JdvRjQTK0nm4sdQ6ELJNePlP-E2ctQ0U1vqExx5hUvf0pFu6ZoSbq1uRZGq-l2JfYI",
  },
];

export const SCHEDULE_DAYS = [
  { label: "Tue", day: "14" },
  { label: "Wed", day: "15" },
  { label: "Thu", day: "16" },
  { label: "Fri", day: "17" },
];

export const SCHEDULE_TIMES = [
  { period: "Morning", time: "9:00 AM" },
  { period: "Lunch", time: "12:30 PM" },
  { period: "Afternoon", time: "3:45 PM" },
];

export const NAV_ITEMS = [
  { href: "/discover", icon: "auto_awesome", label: "Discover" },
  { href: "/matches", icon: "coffee", label: "Matches" },
  { href: "/schedule", icon: "calendar_today", label: "Schedule" },
  { href: "/profile", icon: "person", label: "Profile" },
] as const;
