import styles from "./ProgramOverview.module.css";

const programs = [
  {
    level: "A1",
    japanese: "基礎",
    title: "Japanese Foundations",
    description:
      "Build a strong foundation through hiragana, basic grammar, useful vocabulary, and everyday expressions.",
    topics: ["Hiragana", "Basic grammar", "Daily vocabulary"],
  },
  {
    level: "A2",
    japanese: "初級",
    title: "Elementary Japanese",
    description:
      "Develop practical communication, reading, listening, and preparation skills for the next level.",
    topics: ["Conversation", "Kanji basics", "Reading practice"],
  },
];

export function ProgramOverview() {
  return (
    <section id="programs" className={styles.section}>
      <div className={styles.container}>
        <div className={styles.heading}>
          <div>
            <p className={styles.eyebrow}>Learning Programs</p>

            <h2>Start with the right Japanese level</h2>
          </div>

          <p className={styles.introduction}>
            Our learning programs are designed to help students develop
            practical Japanese skills through guided lessons and accessible
            learning materials.
          </p>
        </div>

        <div className={styles.programGrid}>
          {programs.map((program) => (
            <article key={program.level} className={styles.programCard}>
              <div className={styles.cardHeader}>
                <span className={styles.level}>{program.level}</span>
                <span className={styles.japanese}>{program.japanese}</span>
              </div>

              <h3>{program.title}</h3>
              <p className={styles.description}>{program.description}</p>

              <ul className={styles.topicList}>
                {program.topics.map((topic) => (
                  <li key={topic}>{topic}</li>
                ))}
              </ul>
            </article>
          ))}
        </div>
      </div>
    </section>
  );
}
