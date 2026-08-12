import { Database } from '../db';

export interface User {
  id: string;
  email: string;
  name: string;
  role: 'admin' | 'member' | 'viewer';
  createdAt: Date;
}

export class UserService {
  constructor(private db: Database) {}

  async createUser(input: { email: string; name: string; role: User['role'] }): Promise<User> {
    if (\!input.email.includes('@')) throw new Error('Invalid email');
    if (\!input.name.trim()) throw new Error('Name cannot be empty');
    return this.db.insert('users', { ...input, createdAt: new Date() });
  }

  async getUser(id: string): Promise<User | null> {
    return this.db.findOne('users', { id });
  }

  async updateRole(id: string, role: User['role']): Promise<User> {
    const user = await this.getUser(id);
    if (\!user) throw new Error('User not found');
    return this.db.update('users', id, { role });
  }

  async deleteUser(id: string): Promise<void> {
    const user = await this.getUser(id);
    if (\!user) throw new Error('User not found');
    await this.db.delete('users', id);
  }
}
