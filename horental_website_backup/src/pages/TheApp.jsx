import React from 'react';
import { Smartphone, LayoutDashboard, Bell, ShieldCheck } from 'lucide-react';
import './TheApp.css';

const TheApp = () => {
  return (
    <div className="app-page">
      <div className="app-hero">
        <div className="container app-hero-container">
          <div className="app-hero-content animate-fade-in">
            <div className="badge">Introducing</div>
            <h1 className="page-title">The Ho Rental <span>Web App</span></h1>
            <p className="app-hero-subtitle">
              Built natively with Flutter, our comprehensive web application puts the power of real estate management right at your fingertips.
            </p>
            <div className="app-actions">
              <a href="https://web-five-zeta-lt6h5j4aux.vercel.app" className="btn btn-primary app-btn">Launch Portal</a>
            </div>
          </div>
          <div className="app-hero-image animate-fade-in" style={{animationDelay: '0.2s'}}>
            <div className="mockup-window">
              <div className="mockup-header">
                <span className="dot bg-red"></span>
                <span className="dot bg-yellow"></span>
                <span className="dot bg-green"></span>
              </div>
              <div className="mockup-body">
                <img 
                  src="https://images.unsplash.com/photo-1460925895917-afdab827c52f?auto=format&fit=crop&w=1200&q=80" 
                  alt="Ho Rental Dashboard" 
                  className="dashboard-img"
                />
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="section bg-light">
        <div className="container">
          <div className="text-center mb-5">
            <h2 className="section-title">Everything you need, <span>in one place.</span></h2>
          </div>
          
          <div className="app-features-grid">
            <div className="app-feature-card">
              <LayoutDashboard className="app-icon" />
              <h3>Owner Dashboard</h3>
              <p>Monitor your entire portfolio, view real-time analytics, and track financial performance across all your properties.</p>
            </div>
            <div className="app-feature-card">
              <Smartphone className="app-icon" />
              <h3>Tenant Portal</h3>
              <p>Pay rent instantly, submit maintenance requests, and communicate with property managers seamlessly.</p>
            </div>
            <div className="app-feature-card">
              <Bell className="app-icon" />
              <h3>Instant Notifications</h3>
              <p>Never miss a beat with real-time push notifications for payments, messages, and maintenance updates.</p>
            </div>
            <div className="app-feature-card">
              <ShieldCheck className="app-icon" />
              <h3>Secure Documents</h3>
              <p>Access your leases, tax documents, and property records in our bank-grade encrypted document vault.</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default TheApp;
