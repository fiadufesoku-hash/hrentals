import React from 'react';
import { ArrowRight } from 'lucide-react';
import './Services.css';

const Services = () => {
  return (
    <div className="services-page">
      {/* Editorial Hero */}
      <section className="services-hero">
        <div className="container">
          <p className="overline">Our Expertise</p>
          <h1 className="services-headline">
            Curated Services for<br />
            <span className="text-accent">Every Real Estate Need</span>
          </h1>
        </div>
      </section>

      {/* Alternating Editorial Sections */}
      <div className="services-list">
        
        {/* Service 1 */}
        <section className="service-block">
          <div className="container service-block-container">
            <div className="service-image-side">
              <div className="image-frame">
                <img 
                  src="https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=1000&q=80" 
                  alt="Modern apartment interior" 
                />
              </div>
            </div>
            <div className="service-content-side">
              <span className="service-number">01</span>
              <h2>Leasing of Rooms & Apartments</h2>
              <p className="service-desc">
                Experience comfort without compromise. We curate premium living spaces designed for modern lifestyles. From chic studio apartments to sprawling family homes, our leasing process is transparent, efficient, and tailored entirely to you.
              </p>
              <ul className="elegant-list">
                <li>Short & Long-term flex leases</li>
                <li>Fully furnished luxury options</li>
                <li>Streamlined approval process</li>
              </ul>
            </div>
          </div>
        </section>

        {/* Service 2 */}
        <section className="service-block reverse">
          <div className="container service-block-container">
            <div className="service-image-side">
              <div className="image-frame">
                <img 
                  src="https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=1000&q=80" 
                  alt="Luxury house exterior" 
                />
              </div>
            </div>
            <div className="service-content-side">
              <span className="service-number">02</span>
              <h2>Selling Houses</h2>
              <p className="service-desc">
                Whether you are acquiring your forever home or liquidating an asset, our strategic approach ensures maximum value. We leverage data-driven market insights and unparalleled marketing to connect the right buyers with the perfect properties.
              </p>
              <ul className="elegant-list">
                <li>Bespoke property marketing</li>
                <li>In-depth market analysis</li>
                <li>Expert negotiation strategies</li>
              </ul>
            </div>
          </div>
        </section>

        {/* Service 3 */}
        <section className="service-block">
          <div className="container service-block-container">
            <div className="service-image-side">
              <div className="image-frame">
                <img 
                  src="https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=1000&q=80" 
                  alt="Vast open land" 
                />
              </div>
            </div>
            <div className="service-content-side">
              <span className="service-number">03</span>
              <h2>Lands & Plots</h2>
              <p className="service-desc">
                Secure your future with prime land investments. We offer meticulously verified, litigation-free parcels in high-growth corridors. Perfect for immediate development or long-term portfolio appreciation.
              </p>
              <ul className="elegant-list">
                <li>Verified residential & commercial plots</li>
                <li>Guaranteed legal documentation</li>
                <li>Guided site visitations</li>
              </ul>
            </div>
          </div>
        </section>

        {/* Service 4 */}
        <section className="service-block reverse">
          <div className="container service-block-container">
            <div className="service-image-side">
              <div className="image-frame">
                <img 
                  src="https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=1000&q=80" 
                  alt="Corporate high rise building" 
                />
              </div>
            </div>
            <div className="service-content-side">
              <span className="service-number">04</span>
              <h2>General Real Estate</h2>
              <p className="service-desc">
                A holistic approach to real estate. From day-to-day property management to high-level investment advisory, we act as your dedicated partners, ensuring your real estate journey is seamless and profitable.
              </p>
              <ul className="elegant-list">
                <li>Full-service property management</li>
                <li>Strategic investment advisory</li>
                <li>Real estate consultancy</li>
              </ul>
            </div>
          </div>
        </section>

      </div>
    </div>
  );
};

export default Services;
