import NextAuth from "next-auth";
import GoogleProvider from "next-auth/providers/google";

const handler = NextAuth({
  providers: [
    GoogleProvider({
      clientId: process.env.GOOGLE_CLIENT_ID || "",
      clientSecret: process.env.GOOGLE_CLIENT_SECRET || "",
    }),
  ],
  secret: process.env.NEXTAUTH_SECRET,
  pages: {
    signIn: "/login",
    error: "/login",
  },
  callbacks: {
    async signIn({ user }) {
      return Boolean(user.email);
    },

    async jwt({ token, user }) {
      if (user?.email) {
        token.email = user.email;
        token.username = user.name || user.email;
        token.picture = user.image;
      }

      return token;
    },

    async session({ session, token }) {
      (session.user as any).email = token.email;
      (session.user as any).username = token.username;
      (session.user as any).image = token.picture;
      return session;
    },
  },
});

export { handler as GET, handler as POST };
