import styles from "./LearningModes.module.css";

const learningModes = [
  {
    label: "On campus",
    japanese: "教室",
    title: "Face-to-face classes",
    description:
      "Learn directly with an instructor in a structured classroom environment at our General Santos City location.",
    benefits: [
      "In-person instructor guidance",
      "Classroom learning activities",
      "Direct student interaction",
    ],
    variant: "classroom",
  },
  {
    label: "Remote learning",
    japanese: "オンライン",
    title: "Online classes",
    description:
      "Continue learning Japanese remotely through scheduled online classes and accessible digital materials.",
    benefits: [
      "Learn from your location",
      "Access digital resources",
      "Follow your assigned class",
    ],
    variant: "online",
  },
];

export function LearningModes() {
  return (
    <section id="learning-options" className={styles.section}>
      <div className={styles.container}>
        <div className={styles.heading}>
          <p className={styles.eyebrow}>Learning Options</p>

          <h2>Choose where you learn best</h2>

          <p className={styles.introduction}>
            MG Sakura supports students attending classes in person and those
            learning remotely.
          </p>
        </div>

        <div className={styles.modeGrid}>
          {learningModes.map((mode) => (
            <article
              key={mode.title}
              className={`${styles.modeCard} ${
                mode.variant === "online"
                  ? styles.onlineCard
                  : styles.classroomCard
              }`}
            >
              <div className={styles.cardTop}>
                <span className={styles.label}>{mode.label}</span>

                <span className={styles.japanese} aria-hidden="true">
                  {mode.japanese}
                </span>
              </div>

              <div className={styles.cardContent}>
                <h3>{mode.title}</h3>
                <p>{mode.description}</p>

                <ul className={styles.benefitList}>
                  {mode.benefits.map((benefit) => (
                    <li key={benefit}>
                      <span aria-hidden="true">✓</span>
                      {benefit}
                    </li>
                  ))}
                </ul>
              </div>
            </article>
          ))}
        </div>
      </div>
    </section>
  );
}
