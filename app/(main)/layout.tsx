export default function MainLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="relative min-h-screen bg-surface">
      {children}
      <div className="h-24" />
    </div>
  );
}
