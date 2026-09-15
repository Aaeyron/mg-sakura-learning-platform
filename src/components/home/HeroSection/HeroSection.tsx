import Link from "next/link";

import styles from "./HeroSection.module.css";

export function HeroSection() {
  return (
    <section className={styles.hero}>
      <div className={styles.container}>
        <div className={styles.content}>
          <p className={styles.eyebrow}>Japanese Language Training</p>

          <h1 className={styles.title}>
            Learn Japanese.
            <span> Build your path forward.</span>
          </h1>

          <p className={styles.description}>
            Access practical Japanese lessons and learning materials through
            online or face-to-face classes with MG Sakura Technical Institute.
          </p>

          <div className={styles.actions}>
            <Link href="#programs" className={styles.primaryButton}>
              Explore Programs
            </Link>

            <Link href="/login" className={styles.secondaryButton}>
              Student Login
            </Link>
          </div>

          <ul className={styles.learningOptions}>
            <li>Online classes</li>
            <li>Face-to-face classes</li>
            <li>General Santos City</li>
          </ul>
        </div>

        <div className={styles.visual} aria-hidden="true">
          <div className={styles.visualAccent} />

          <div className={styles.languageCard}>
            <span className={styles.japaneseText}>日本語</span>
            <p>Japanese Language</p>

            <div className={styles.levels}>
              <span>A1</span>
              <span>A2</span>
            </div>
          </div>

          <div className={styles.supportCard}>
            <span>学ぶ</span>
            <p>Learn · Practice · Prepare</p>
          </div>
        </div>
      </div>
    </section>
  );
}
