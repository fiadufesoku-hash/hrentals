import React from 'react';
import { Link } from 'react-router-dom';
import { ArrowRight, Shield, Zap, Home as HomeIcon } from 'lucide-react';
import './Home.css';

const Home = () => {
  return (
    <div className="home-corporate">
      {/* Hero Section */}
      <section className="corp-hero">
        <div className="container">
          <div className="corp-hero-grid">
            <div className="corp-hero-content animate-fade-in">
              <h1 className="corp-hero-title">
                Experience Modern <br />
                <span className="gradient-text">Real Estate</span>
              </h1>
              <p className="corp-hero-subtitle">
                Leasing, selling, and managing properties with unmatched transparency and technological innovation.
              </p>
              <div className="corp-hero-actions">
                <Link to="/services" className="btn btn-primary corp-btn">
                  Our Services
                </Link>
                <Link to="/about" className="btn btn-outline corp-btn">
                  Who We Are
                </Link>
              </div>
            </div>
            <div className="corp-hero-image-wrapper animate-fade-in" style={{ animationDelay: '0.2s' }}>
              <img 
                src="https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?auto=format&fit=crop&w=1200&q=80" 
                alt="Modern luxury home" 
                className="corp-hero-image"
              />
            </div>
          </div>
        </div>
      </section>

      {/* Minimal Features Section */}
      <section className="section corp-features">
        <div className="container">
          <div className="features-grid">
            <div className="feature-item">
              <Zap className="feature-icon" size={32} />
              <h3>Fast & Seamless</h3>
              <p>Our platform ensures quick property matching and effortless transactions.</p>
            </div>
            
            <div className="feature-item">
              <Shield className="feature-icon" size={32} />
              <h3>Secure Process</h3>
              <p>Bank-grade security and verified listings guarantee peace of mind.</p>
            </div>
            
            <div className="feature-item">
              <HomeIcon className="feature-icon" size={32} />
              <h3>Premium Quality</h3>
              <p>We curate only the finest properties and lands for our clients.</p>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
};

export default Home;
