import React, { useState } from 'react';
import { Mail, Phone, MapPin, Send } from 'lucide-react';
import './Contact.css';

const Contact = () => {
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    subject: '',
    message: ''
  });

  const handleChange = (e) => {
    setFormData({
      ...formData,
      [e.target.name]: e.target.value
    });
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    alert('Thank you for your message. We will get back to you soon!');
    setFormData({ name: '', email: '', subject: '', message: '' });
  };

  return (
    <div className="contact-page">
      <div className="page-hero">
        <div className="container">
          <h1 className="page-title animate-fade-in">Contact Us</h1>
          <p className="page-subtitle animate-fade-in">We'd love to hear from you. Reach out to our team.</p>
        </div>
      </div>

      <div className="container section">
        <div className="contact-grid">
          <div className="contact-info">
            <h2>Get In Touch</h2>
            <p className="contact-text">
              Whether you have a question about properties, pricing, or anything else, our team is ready to answer all your questions.
            </p>
            
            <div className="info-item">
              <div className="info-icon"><MapPin /></div>
              <div>
                <h3>Our Office</h3>
                <p>123 Rental Street, Suite 100<br/>New York, NY 10001</p>
              </div>
            </div>
            
            <div className="info-item">
              <div className="info-icon"><Phone /></div>
              <div>
                <h3>Phone</h3>
                <p>(555) 123-4567<br/>Mon-Fri 9am-6pm EST</p>
              </div>
            </div>
            
            <div className="info-item">
              <div className="info-icon"><Mail /></div>
              <div>
                <h3>Email</h3>
                <p>hello@horentals.com<br/>support@horentals.com</p>
              </div>
            </div>
          </div>

          <div className="contact-form-container">
            <form className="contact-form" onSubmit={handleSubmit}>
              <div className="form-group">
                <label htmlFor="name">Full Name</label>
                <input 
                  type="text" 
                  id="name" 
                  name="name" 
                  value={formData.name} 
                  onChange={handleChange} 
                  required 
                />
              </div>
              <div className="form-group">
                <label htmlFor="email">Email Address</label>
                <input 
                  type="email" 
                  id="email" 
                  name="email" 
                  value={formData.email} 
                  onChange={handleChange} 
                  required 
                />
              </div>
              <div className="form-group">
                <label htmlFor="subject">Subject</label>
                <input 
                  type="text" 
                  id="subject" 
                  name="subject" 
                  value={formData.subject} 
                  onChange={handleChange} 
                  required 
                />
              </div>
              <div className="form-group">
                <label htmlFor="message">Message</label>
                <textarea 
                  id="message" 
                  name="message" 
                  rows="5" 
                  value={formData.message} 
                  onChange={handleChange} 
                  required 
                ></textarea>
              </div>
              <button type="submit" className="btn btn-primary submit-btn">
                <Send size={18} /> Send Message
              </button>
            </form>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Contact;
