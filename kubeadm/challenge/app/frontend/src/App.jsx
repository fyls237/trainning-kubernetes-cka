import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Terminal, Database, Server, Code, Plus, ExternalLink, Loader2 } from 'lucide-react';

const API_URL = "/api"; // Sera redirigé par Nginx vers le backend

function App() {
    const [projects, setProjects] = useState([]);
    const [loading, setLoading] = useState(true);
    const [showForm, setShowForm] = useState(false);
    const [newProject, setNewProject] = useState({ title: '', description: '', tech_stack: '' });

    // Fetch Projects
    useEffect(() => {
        fetch(`${API_URL}/projects`)
            .then(res => res.json())
            .then(data => {
                setProjects(data);
                setLoading(false);
            })
            .catch(err => {
                console.error("Erreur API:", err);
                setLoading(false);
            });
    }, []);

    const handleSubmit = (e) => {
        e.preventDefault();
        const payload = {
            ...newProject,
            tech_stack: newProject.tech_stack.split(',').map(t => t.trim())
        };

        fetch(`${API_URL}/projects`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        })
            .then(res => res.json())
            .then(saved => {
                setProjects([saved, ...projects]);
                setShowForm(false);
                setNewProject({ title: '', description: '', tech_stack: '' });
            });
    };

    return (
        <div className="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-black text-slate-100 p-8">

            {/* Header façon Terminal */}
            <motion.header
                initial={{ y: -50, opacity: 0 }}
                animate={{ y: 0, opacity: 1 }}
                className="max-w-5xl mx-auto mb-12"
            >
                <div className="bg-slate-900/80 backdrop-blur-md border border-slate-700 rounded-lg p-4 shadow-2xl">
                    <div className="flex items-center gap-2 mb-4 border-b border-slate-700 pb-2">
                        <div className="w-3 h-3 rounded-full bg-red-500" />
                        <div className="w-3 h-3 rounded-full bg-yellow-500" />
                        <div className="w-3 h-3 rounded-full bg-green-500" />
                        <span className="ml-4 text-xs font-mono text-slate-400">user@k8s-cluster:~/portfolio</span>
                    </div>
                    <div className="font-mono space-y-2">
                        <p className="text-green-400">$ kubectl get skills</p>
                        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm text-slate-300 mt-2">
                            <span className="flex items-center gap-2"><Server size={14} /> Kubernetes CKA</span>
                            <span className="flex items-center gap-2"><Database size={14} /> PostgreSQL</span>
                            <span className="flex items-center gap-2"><Code size={14} /> Python & React</span>
                            <span className="flex items-center gap-2"><Terminal size={14} /> DevOps & CI/CD</span>
                        </div>
                    </div>
                </div>
            </motion.header>

            {/* Main Content */}
            <main className="max-w-5xl mx-auto">
                <div className="flex justify-between items-center mb-8">
                    <h1 className="text-3xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-cyan-400 to-blue-600">
                        Deployed Projects
                    </h1>
                    <button
                        onClick={() => setShowForm(!showForm)}
                        className="flex items-center gap-2 bg-cyan-600 hover:bg-cyan-500 text-white px-4 py-2 rounded-md transition-all"
                    >
                        <Plus size={18} /> Add Project
                    </button>
                </div>

                {/* Formulaire (Collapse) */}
                <AnimatePresence>
                    {showForm && (
                        <motion.form
                            initial={{ height: 0, opacity: 0 }}
                            animate={{ height: 'auto', opacity: 1 }}
                            exit={{ height: 0, opacity: 0 }}
                            className="bg-slate-800/50 backdrop-blur border border-slate-700 p-6 rounded-xl mb-8 overflow-hidden"
                            onSubmit={handleSubmit}
                        >
                            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                <input
                                    type="text" placeholder="Project Title" className="bg-slate-900 border border-slate-700 rounded p-2 text-white"
                                    value={newProject.title} onChange={e => setNewProject({ ...newProject, title: e.target.value })}
                                />
                                <input
                                    type="text" placeholder="Tech Stack (comma separated)" className="bg-slate-900 border border-slate-700 rounded p-2 text-white"
                                    value={newProject.tech_stack} onChange={e => setNewProject({ ...newProject, tech_stack: e.target.value })}
                                />
                                <textarea
                                    placeholder="Description" className="bg-slate-900 border border-slate-700 rounded p-2 text-white md:col-span-2"
                                    value={newProject.description} onChange={e => setNewProject({ ...newProject, description: e.target.value })}
                                />
                            </div>
                            <button type="submit" className="mt-4 bg-green-600 text-white px-6 py-2 rounded">Deploy</button>
                        </motion.form>
                    )}
                </AnimatePresence>

                {/* Liste des Projets */}
                {loading ? (
                    <div className="flex justify-center py-20"><Loader2 className="animate-spin text-cyan-500" size={48} /></div>
                ) : (
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                        {projects.map((project, i) => (
                            <motion.div
                                key={project.id || i}
                                initial={{ opacity: 0, scale: 0.9 }}
                                animate={{ opacity: 1, scale: 1 }}
                                transition={{ delay: i * 0.1 }}
                                className="group relative bg-slate-800/40 hover:bg-slate-800/80 border border-slate-700/50 hover:border-cyan-500/50 rounded-xl p-6 transition-all duration-300"
                            >
                                <div className="absolute top-0 right-0 p-4 opacity-0 group-hover:opacity-100 transition-opacity">
                                    <ExternalLink size={20} className="text-cyan-400" />
                                </div>
                                <h3 className="text-xl font-bold text-white mb-2">{project.title}</h3>
                                <p className="text-slate-400 text-sm mb-4 h-12 overflow-hidden">{project.description}</p>
                                <div className="flex flex-wrap gap-2 mt-auto">
                                    {project.tech_stack && project.tech_stack.map(tech => (
                                        <span key={tech} className="px-2 py-1 bg-cyan-900/30 text-cyan-300 text-xs rounded border border-cyan-800/50">
                                            {tech}
                                        </span>
                                    ))}
                                </div>
                                <div className="mt-4 pt-4 border-t border-slate-700/50 flex justify-between text-xs text-slate-500 font-mono">
                                    <span>ID: {project.id}</span>
                                    <span>{new Date(project.created_at).toLocaleDateString()}</span>
                                </div>
                            </motion.div>
                        ))}

                        {projects.length === 0 && (
                            <div className="col-span-2 text-center text-slate-500 py-10 border border-dashed border-slate-700 rounded-xl">
                                No projects found in database. Start adding some!
                            </div>
                        )}
                    </div>
                )}
            </main>
        </div>
    );
}

export default App;
