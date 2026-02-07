import Foundation
import Supabase

enum SupabaseConfig {
    // Supabase project values
    static let urlString = "https://fcnweiksuonbkkhvgbih.supabase.co"
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZjbndlaWtzdW9uYmtraHZnYmloIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA0MjIxOTksImV4cCI6MjA4NTk5ODE5OX0.IpEvjOZZp_-84qe8zKgc3-fxs6PDESZCWOljL46oanE"
    
    // Shared Supabase client instance
    static let client: SupabaseClient = {
        guard let url = URL(string: urlString) else {
            fatalError("Invalid Supabase URL")
        }
        return SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
    }()
}
