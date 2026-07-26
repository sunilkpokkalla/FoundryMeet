"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { Icon } from "@/components/icon";

const TOTAL_STEPS = 4;

const ROLES = [
  {
    icon: "rocket_launch",
    title: "Founder",
    subtitle: "Visionary and strategist",
  },
  {
    icon: "architecture",
    title: "Builder",
    subtitle: "Engineer or Designer",
  },
  {
    icon: "group_add",
    title: "Early Hire",
    subtitle: "First 10 employees",
  },
];

const STAGES = ["Idea", "Seed", "Series A+"];

const SKILLS = [
  { icon: "code", label: "Engineering" },
  { icon: "palette", label: "Design" },
  { icon: "payments", label: "Sales" },
  { icon: "trending_up", label: "Growth" },
  { icon: "inventory_2", label: "Product" },
  { icon: "gavel", label: "Legal" },
  { icon: "psychology", label: "AI/ML" },
];

const GOALS = [
  {
    icon: "handshake",
    title: "Find a Cofounder",
    description:
      "Search for partners with complementary skills and shared values.",
  },
  {
    icon: "person_add",
    title: "Hire Early Team",
    description: "Find the builders who will help you lay the first bricks.",
  },
  {
    icon: "school",
    title: "Get Advice",
    description: "Connect with experienced advisors and domain experts.",
  },
];

function confettiEffect() {
  for (let i = 0; i < 50; i++) {
    const confetti = document.createElement("div");
    confetti.className =
      "pointer-events-none absolute h-2 w-2 rounded-full";
    confetti.style.backgroundColor = ["#745b20", "#ffdb94", "#0d1c2e"][
      Math.floor(Math.random() * 3)
    ] as string;
    confetti.style.left = `${Math.random() * 100}vw`;
    confetti.style.top = "-10px";
    document.body.appendChild(confetti);

    const duration = 2000 + Math.random() * 3000;
    confetti
      .animate(
        [
          { transform: "translateY(0) rotate(0)", opacity: 1 },
          {
            transform: `translateY(100vh) rotate(${Math.random() * 360}deg)`,
            opacity: 0,
          },
        ],
        {
          duration,
          easing: "cubic-bezier(0.25, 0.46, 0.45, 0.94)",
        },
      )
      .onfinish = () => confetti.remove();
  }
}

export function OnboardingWizard() {
  const router = useRouter();
  const [step, setStep] = useState(1);
  const [selectedRole, setSelectedRole] = useState<string | null>(null);
  const [selectedStage, setSelectedStage] = useState<string | null>(null);
  const [selectedSkills, setSelectedSkills] = useState<string[]>([]);
  const [selectedGoal, setSelectedGoal] = useState<string | null>(null);
  const [completing, setCompleting] = useState(false);
  const [completed, setCompleted] = useState(false);

  function toggleSkill(skill: string) {
    setSelectedSkills((current) =>
      current.includes(skill)
        ? current.filter((item) => item !== skill)
        : [...current, skill],
    );
  }

  function handleNext() {
    if (step < TOTAL_STEPS) {
      setStep((current) => current + 1);
      window.scrollTo({ top: 0, behavior: "smooth" });
      return;
    }

    setCompleting(true);
    window.setTimeout(() => {
      setCompleting(false);
      setCompleted(true);
      confettiEffect();
      window.setTimeout(() => router.push("/discover"), 2000);
    }, 1500);
  }

  function handleBack() {
    if (step > 1) {
      setStep((current) => current - 1);
      window.scrollTo({ top: 0, behavior: "smooth" });
    }
  }

  return (
    <main className="relative min-h-screen">
      <div className="flex w-full flex-col">
        <div className="flex flex-col gap-2 px-gutter py-6">
          <div className="flex items-center justify-between">
            <span className="text-label-sm tracking-widest text-on-surface-variant uppercase">
              Step {step} of {TOTAL_STEPS}
            </span>
            <span className="text-label-sm font-bold text-secondary">
              FoundryMeet
            </span>
          </div>
          <div className="h-1 w-full overflow-hidden rounded-full bg-surface-container">
            <div
              className="h-full bg-secondary transition-all duration-500 ease-out"
              style={{ width: `${(step / TOTAL_STEPS) * 100}%` }}
            />
          </div>
        </div>

        <div className="relative overflow-hidden px-gutter pb-gutter">
          {step === 1 && (
            <div className="flex flex-col gap-8">
              <header className="flex flex-col gap-2">
                <h1 className="text-headline-lg font-semibold text-on-surface">
                  Tell us your story
                </h1>
                <p className="text-body-md text-on-surface-variant italic">
                  &quot;Meet the people building the future.&quot;
                </p>
              </header>
              <section className="flex flex-col gap-4">
                <label className="text-label-md text-on-surface-variant">
                  What is your primary role?
                </label>
                <div className="grid grid-cols-1 gap-3">
                  {ROLES.map((role) => (
                    <button
                      key={role.title}
                      type="button"
                      onClick={() => setSelectedRole(role.title)}
                      className={`option-card group flex items-center justify-between rounded-xl bg-surface-container-low p-5 text-left transition-all active:scale-95 ${
                        selectedRole === role.title
                          ? "selected bg-secondary-container"
                          : ""
                      }`}
                    >
                      <div className="flex items-center gap-4">
                        <div
                          className={`flex h-12 w-12 items-center justify-center rounded-full bg-surface-container-highest transition-colors ${
                            selectedRole === role.title
                              ? "bg-secondary text-on-secondary"
                              : ""
                          }`}
                        >
                          <Icon name={role.icon} />
                        </div>
                        <div>
                          <p className="text-headline-sm font-semibold text-on-surface">
                            {role.title}
                          </p>
                          <p className="text-label-sm text-on-surface-variant">
                            {role.subtitle}
                          </p>
                        </div>
                      </div>
                      <Icon
                        name="check_circle"
                        className={`text-secondary ${
                          selectedRole === role.title
                            ? "opacity-100"
                            : "opacity-0"
                        }`}
                      />
                    </button>
                  ))}
                </div>
              </section>
            </div>
          )}

          {step === 2 && (
            <div className="flex flex-col gap-8">
              <header className="flex flex-col gap-2">
                <h1 className="text-headline-lg font-semibold text-on-surface">
                  Context is key
                </h1>
                <p className="text-body-md text-on-surface-variant">
                  Where are you building, and how far along is the journey?
                </p>
              </header>
              <div className="flex flex-col gap-6">
                <div className="flex flex-col gap-3">
                  <label className="text-label-md text-on-surface-variant">
                    Base Location
                  </label>
                  <div className="relative">
                    <input
                      type="text"
                      placeholder="e.g. San Francisco, CA"
                      className="w-full rounded-xl border-b-2 border-secondary/20 bg-surface-container-lowest px-5 py-4 text-body-md text-on-surface outline-none transition-all focus:border-secondary"
                    />
                    <Icon
                      name="location_on"
                      className="absolute top-1/2 right-4 -translate-y-1/2 text-on-surface-variant"
                    />
                  </div>
                </div>
                <div className="flex flex-col gap-3">
                  <label className="text-label-md text-on-surface-variant">
                    Startup Stage
                  </label>
                  <div className="grid grid-cols-3 gap-2">
                    {STAGES.map((stage) => (
                      <button
                        key={stage}
                        type="button"
                        onClick={() => setSelectedStage(stage)}
                        className={`rounded-full py-3 text-label-md transition-all active:scale-95 ${
                          selectedStage === stage
                            ? "bg-secondary text-on-secondary"
                            : "bg-surface-container text-on-surface"
                        }`}
                      >
                        {stage}
                      </button>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          )}

          {step === 3 && (
            <div className="flex flex-col gap-8">
              <header className="flex flex-col gap-2">
                <h1 className="text-headline-lg font-semibold text-on-surface">
                  Your Superpowers
                </h1>
                <p className="text-body-md text-on-surface-variant">
                  Select the skills you bring to the table.
                </p>
              </header>
              <div className="flex flex-wrap gap-2">
                {SKILLS.map((skill) => {
                  const selected = selectedSkills.includes(skill.label);
                  return (
                    <button
                      key={skill.label}
                      type="button"
                      onClick={() => toggleSkill(skill.label)}
                      className={`flex items-center gap-2 rounded-full px-5 py-2 text-label-md transition-all active:scale-95 ${
                        selected
                          ? "bg-secondary text-on-secondary"
                          : "bg-surface-container-low text-on-surface"
                      }`}
                    >
                      <Icon name={skill.icon} className="text-[18px]" />
                      {skill.label}
                    </button>
                  );
                })}
              </div>
            </div>
          )}

          {step === 4 && (
            <div className="flex flex-col gap-8">
              <header className="flex flex-col gap-2">
                <h1 className="text-headline-lg font-semibold text-on-surface">
                  The North Star
                </h1>
                <p className="text-body-md text-on-surface-variant">
                  What is your primary goal right now?
                </p>
              </header>
              <div className="grid grid-cols-1 gap-4">
                {GOALS.map((goal) => (
                  <button
                    key={goal.title}
                    type="button"
                    onClick={() => setSelectedGoal(goal.title)}
                    className={`option-card group flex flex-col gap-2 rounded-2xl bg-surface-container-low p-6 text-left transition-all ${
                      selectedGoal === goal.title
                        ? "selected bg-secondary-container"
                        : ""
                    }`}
                  >
                    <div className="flex w-full items-center justify-between">
                      <Icon name={goal.icon} className="text-secondary" />
                      <div
                        className={`flex h-5 w-5 items-center justify-center rounded-full border-2 ${
                          selectedGoal === goal.title
                            ? "border-secondary bg-secondary"
                            : "border-secondary/30"
                        }`}
                      >
                        <div className="h-2 w-2 rounded-full bg-white" />
                      </div>
                    </div>
                    <h3 className="mt-2 text-headline-sm font-semibold text-on-surface">
                      {goal.title}
                    </h3>
                    <p className="text-body-md text-on-surface-variant">
                      {goal.description}
                    </p>
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>

        <div className="fixed right-0 bottom-0 left-0 flex items-center gap-4 bg-surface/80 p-gutter backdrop-blur-lg">
          {step > 1 && (
            <button
              type="button"
              onClick={handleBack}
              className="flex-1 rounded-xl bg-surface-container-high py-4 text-label-md text-on-surface-variant transition-all active:scale-95"
            >
              Back
            </button>
          )}
          <button
            type="button"
            onClick={handleNext}
            disabled={completing}
            className={`flex flex-[2] items-center justify-center gap-2 rounded-xl py-4 text-label-md text-on-primary shadow-xl transition-all active:scale-95 ${
              step === TOTAL_STEPS ? "bg-secondary" : "bg-primary"
            }`}
          >
            {completing ? (
              <Icon name="sync" className="animate-spin" />
            ) : completed ? (
              <>
                <Icon name="celebration" />
                Welcome aboard!
              </>
            ) : step === TOTAL_STEPS ? (
              "Start Matching"
            ) : (
              "Continue"
            )}
          </button>
        </div>

        <div className="h-28" />
      </div>
    </main>
  );
}
