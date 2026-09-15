import Link from "next/link";

import styles from "./HomeHeader.module.css";

const navigationLinks = [
  {
    label: "Programs",
    href: "#programs",
  },
  {
    label: "Learning Options",
    href: "#learning-options",
  },
  {
    label: "About",
    href: "#about",
  },
];

export function HomeHeader() {
  return (
    <header className={styles.header}>
      <div className={styles.container}>
        <Link href="/" className={styles.brand} aria-label="MG Sakura home">
          <span className={styles.brandMark} aria-hidden="true">
            桜
          </span>

          <span className={styles.brandText}>
            <strong>MG Sakura</strong>
            <small>Technical Institute</small>
          </span>
        </Link>

        <nav className={styles.desktopNavigation} aria-label="Main navigation">
          {navigationLinks.map((link) => (
            <Link key={link.href} href={link.href}>
              {link.label}
            </Link>
          ))}
        </nav>

        <div className={styles.desktopActions}>
          <Link href="/login" className={styles.loginLink}>
            Student Login
          </Link>
        </div>

        <details className={styles.mobileMenu}>
          <summary className={styles.menuButton}>
            <span className={styles.menuIcon} aria-hidden="true">
              <span />
              <span />
              <span />
            </span>

            <span className={styles.menuLabel}>Menu</span>
          </summary>

          <nav
            className={styles.mobileNavigation}
            aria-label="Mobile navigation"
          >
            {navigationLinks.map((link) => (
              <Link key={link.href} href={link.href}>
                {link.label}
              </Link>
            ))}

            <Link href="/login" className={styles.mobileLoginLink}>
              Student Login
            </Link>
          </nav>
        </details>
      </div>
    </header>
  );
}
