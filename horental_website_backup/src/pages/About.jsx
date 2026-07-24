import React from 'react';
import './About.css';

const About = () => {
  return (
    <div className="about-page">
      {/* Immersive Hero */}
      <section className="about-hero">
        <div className="about-hero-image">
          <img 
            src="https://images.unsplash.com/photo-1497366216548-37526070297c?auto=format&fit=crop&w=1920&q=80" 
            alt="Modern office architecture" 
          />
          <div className="about-hero-overlay"></div>
        </div>
        <div className="container about-hero-content">
          <h1 className="about-headline">We don't just find properties.<br/>We engineer lifestyles.</h1>
        </div>
      </section>

      {/* Bold Mission Statement */}
      <section className="mission-section">
        <div className="container">
          <div className="mission-content">
            <span className="overline-dark">Our Manifesto</span>
            <h2>
              Ho Rental was born from a singular vision: to dismantle the antiquated complexities of real estate. We replaced endless paperwork with elegant software, and transactional relationships with dedicated concierge service.
            </h2>
          </div>
        </div>
      </section>

      {/* The Difference / Staggered Layout */}
      <section className="difference-section">
        <div className="container">
          <div className="difference-grid">
            <div className="difference-text">
              <h3>The New Standard</h3>
              <p>
                Today, we manage a highly curated portfolio of properties, providing our owners with total peace of mind and our tenants with spaces they are proud to call home.
              </p>
              <p>
                By pairing decades of industry expertise with our custom-built, natively integrated Flutter applications, we deliver a real estate experience that is uncompromisingly efficient and deeply personalized.
              </p>
              
              <div className="about-metrics">
                <div className="metric">
                  <h4>500+</h4>
                  <span>Exclusive Properties</span>
                </div>
                <div className="metric">
                  <h4>98%</h4>
                  <span>Client Retention</span>
                </div>
              </div>
            </div>
            <div className="difference-image">
              <img 
                src="https://images.unsplash.com/photo-1560518883-ce09059eeffa?auto=format&fit=crop&w=800&q=80" 
                alt="Our corporate team" 
              />
            </div>
          </div>
        </div>
      </section>
    </div>
  );
};

export default About;
