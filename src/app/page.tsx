import { HeroSection } from "@/components/home/HeroSection/HeroSection";
import { HomeHeader } from "@/components/home/HomeHeader/HomeHeader";

export default function HomePage() {
  return (
    <>
      <HomeHeader />

      <main>
        <HeroSection />
      </main>
    </>
  );
}