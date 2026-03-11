import { useState, type FormEvent } from "react";
import { login } from "../api";
import { setToken } from "../lib/auth";
import { Utensils, Loader2, AlertCircle } from "lucide-react";

interface LoginPageProps {
  onLogin: () => void;
}

export function LoginPage({ onLogin }: LoginPageProps) {
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);

    try {
      const token = await login(password);
      setToken(token);
      onLogin();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Login failed");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center">
      <div className="w-full max-w-sm mx-4">
        <div className="flex flex-col items-center mb-8">
          <div className="p-4 rounded-2xl bg-gradient-to-br from-cal/20 to-protein/20 border border-cal/20 mb-4">
            <Utensils className="w-8 h-8 text-cal" />
          </div>
          <h1 className="text-2xl font-bold tracking-tight">
            MetOS
          </h1>
          <p className="text-xs opacity-50 mt-1">
            Metabolic Operating System
          </p>
        </div>

        <div className="glass p-6">
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label
                htmlFor="password"
                className="block text-sm font-medium mb-1.5"
              >
                Hasło
              </label>
              <input
                id="password"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full px-3 py-2 rounded-lg bg-surface-raised border border-white/10 text-sm focus:outline-none focus:ring-2 focus:ring-cal/50"
                placeholder="Hasło"
                autoComplete="current-password"
                autoFocus
                required
              />
            </div>

            {error && (
              <div className="flex items-center gap-2 p-3 rounded-lg bg-purine-high/10 border border-purine-high/20">
                <AlertCircle className="w-4 h-4 text-purine-high shrink-0" />
                <p className="text-xs text-purine-high">{error}</p>
              </div>
            )}

            <button
              type="submit"
              disabled={loading}
              className="w-full py-2.5 rounded-lg bg-cal text-black text-sm font-medium hover:bg-cal/90 transition-colors disabled:opacity-50 flex items-center justify-center gap-2"
            >
              {loading ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  Logowanie...
                </>
              ) : (
                "Zaloguj"
              )}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}
