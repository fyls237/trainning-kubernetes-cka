/** @type {import('tailwindcss').Config} */
export default {
    content: [
        "./index.html",
        "./src/**/*.{js,ts,jsx,tsx}",
    ],
    theme: {
        extend: {
            colors: {
                dark: {
                    bg: '#0F172A',
                    card: '#1E293B',
                    text: '#F8FAFC',
                    accent: '#38BDF8'
                }
            }
        },
    },
    plugins: [],
}
