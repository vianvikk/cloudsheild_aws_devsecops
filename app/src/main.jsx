import React from 'react';
import { createRoot } from 'react-dom/client';
import './style.css';

function App() {
  return <main className="shell">
    <header><span className="badge">CLOUDSHIELD / DEVSECOPS</span><h1>Build. Secure. Deploy. Monitor.</h1>
      <p className="subtitle">A sample application running on Amazon EKS.</p></header>
    <section className="grid">
      <article><span className="icon">✓</span><h2>Secure delivery</h2><p>Source changes are tested and scanned before container images are published.</p></article>
      <article><span className="icon">↗</span><h2>Cloud native</h2><p>Docker images are stored in Amazon ECR and deployed through Kubernetes.</p></article>
      <article><span className="icon">◉</span><h2>Observable</h2><p>Prometheus and Grafana provide workload and cluster visibility.</p></article>
    </section>
    <footer><span className="status"></span> Application is healthy <code>/health</code></footer>
  </main>;
}
createRoot(document.getElementById('root')).render(<App />);
