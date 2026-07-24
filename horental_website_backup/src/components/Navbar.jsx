import React, { useState, useEffect } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { Home, Info, Briefcase, Smartphone, Mail, Menu, X } from 'lucide-react';
import './Navbar.css';

const Navbar = () => {
  const [isOpen, setIsOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);
  const location = useLocation();

  useEffect(() => {
    const handleScroll = () => {
      setScrolled(window.scrollY > 50);
    };
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  const toggleMenu = () => setIsOpen(!isOpen);

  const navItems = [
    { path: '/', label: 'Home', icon: <Home size={18} /> },
    { path: '/about', label: 'About', icon: <Info size={18} /> },
    { path: '/services', label: 'Services', icon: <Briefcase size={18} /> },
    { path: '/app', label: 'Our App', icon: <Smartphone size={18} /> },
    { path: '/contact', label: 'Contact', icon: <Mail size={18} /> },
  ];

  return (
    <div className="navbar-wrapper">
      <nav className={`navbar-pill ${scrolled ? 'scrolled' : ''}`}>
        <Link to="/" className="nav-logo">
          <span className="logo-text">Ho Rental</span>
        </Link>
        
        <div className={`nav-links ${isOpen ? 'active' : ''}`}>
          {navItems.map((item) => (
            <Link 
              key={item.path}
              to={item.path} 
              className={`nav-link ${location.pathname === item.path ? 'active' : ''}`}
              onClick={() => setIsOpen(false)}
            >
              <span className="nav-icon">{item.icon}</span>
              <span className="nav-label">{item.label}</span>
            </Link>
          ))}
          <a href="https://web-five-zeta-lt6h5j4aux.vercel.app" className="nav-cta btn-primary" onClick={() => setIsOpen(false)}>
            Launch App
          </a>
        </div>

        <button className="mobile-menu-toggle" onClick={toggleMenu} aria-label="Toggle menu">
          {isOpen ? <X size={24} /> : <Menu size={24} />}
        </button>
      </nav>
    </div>
  );
};

export default Navbar;
