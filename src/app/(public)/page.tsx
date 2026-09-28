import { HeroSection } from "@/components/home/HeroSection/HeroSection";
import { HomeHeader } from "@/components/home/HomeHeader/HomeHeader";
import { LearningModes } from "@/components/home/LearningModes/LearningModes";
import { ProgramOverview } from "@/components/home/ProgramOverview/ProgramOverview";

export default function HomePage() {
  return (
    <>
      <HomeHeader />

      <main>
        <HeroSection />
        <ProgramOverview />
        <LearningModes />
      </main>
    </>
  );
}
