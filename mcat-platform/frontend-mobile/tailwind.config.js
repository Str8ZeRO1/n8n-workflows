/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        dark: {
          bg: '#0f172a',        // slate-900
          card: '#1e293b',      // slate-800
          border: '#334155',    // slate-700
          text: '#f1f5f9',      // slate-100
          muted: '#94a3b8',     // slate-400
        },
        primary: {
          DEFAULT: '#3b82f6',   // blue-500
          dark: '#2563eb',      // blue-600
          light: '#60a5fa',     // blue-400
        },
        success: {
          DEFAULT: '#10b981',   // emerald-500
          dark: '#059669',      // emerald-600
        },
        danger: {
          DEFAULT: '#ef4444',   // red-500
          dark: '#dc2626',      // red-600
        },
        warning: {
          DEFAULT: '#f59e0b',   // amber-500
          dark: '#d97706',      // amber-600
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        mono: ['Fira Code', 'monospace'],
      },
      boxShadow: {
        'dark-sm': '0 1px 2px 0 rgba(0, 0, 0, 0.5)',
        'dark-md': '0 4px 6px -1px rgba(0, 0, 0, 0.5)',
        'dark-lg': '0 10px 15px -3px rgba(0, 0, 0, 0.5)',
        'dark-xl': '0 20px 25px -5px rgba(0, 0, 0, 0.5)',
      },
    },
  },
  plugins: [],
}
