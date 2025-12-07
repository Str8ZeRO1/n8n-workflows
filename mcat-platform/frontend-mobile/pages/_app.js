import '../styles/globals.css';
import { useEffect } from 'react';
import { useAuthStore } from '../lib/store';
import { Toaster } from 'react-hot-toast';

export default function App({ Component, pageProps }) {
  const loadFromStorage = useAuthStore((state) => state.loadFromStorage);
  
  useEffect(() => {
    loadFromStorage();
  }, []);
  
  return (
    <>
      <Component {...pageProps} />
      <Toaster position="top-right" />
    </>
  );
}
