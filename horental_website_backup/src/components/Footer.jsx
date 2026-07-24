import React from 'react';
import { Link } from 'react-router-dom';
import { Home, Mail, Phone, MapPin } from 'lucide-react';
import './Footer.css';

const Footer = () => {
  return (
    <footer className="footer">
      <div className="container footer-container">
        <div className="footer-section brand-section">
          <Link to="/" className="footer-logo">
            <Home className="footer-logo-icon" />
            <span>Ho Rental</span>
          </Link>
          <p className="footer-description">
            Find your dream rental home today. We offer a curated selection of the finest properties for every lifestyle.
          </p>
          <div className="social-links">
            <a href="#" className="social-icon">FB</a>
            <a href="#" className="social-icon">TW</a>
            <a href="#" className="social-icon">IG</a>
          </div>
        </div>

        <div className="footer-section">
          <h4 className="footer-title">Quick Links</h4>
          <ul className="footer-links">
            <li><Link to="/">Home</Link></li>
            <li><Link to="/about">About Us</Link></li>
            <li><Link to="/services">Services</Link></li>
            <li><Link to="/app">Our App</Link></li>
          </ul>
        </div>

        <div className="footer-section">
          <h4 className="footer-title">Connect</h4>
          <ul className="footer-links">
            <li><Link to="/contact">Contact Support</Link></li>
            <li><a href="#">Terms of Service</a></li>
            <li><a href="#">Privacy Policy</a></li>
          </ul>
        </div>

        <div className="footer-section">
          <h4 className="footer-title">Contact Us</h4>
          <ul className="footer-contact">
            <li><MapPin size={18} /> 123 Rental Street, NY 10001</li>
            <li><Phone size={18} /> (555) 123-4567</li>
            <li><Mail size={18} /> hello@horentals.com</li>
          </ul>
        </div>
      </div>
      
      <div className="footer-bottom">
        <div className="container">
          <p>&copy; {new Date().getFullYear()} Ho Rental. All rights reserved.</p>
        </div>
      </div>
    </footer>
  );
};

export default Footer;
