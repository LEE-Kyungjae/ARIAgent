import path from "path";
import { DATA_DIR, readJsonSync, writeJsonSync } from "../infra/data.js";
import { Task } from "../models/task.js";

const TASKS_FILE = path.join(DATA_DIR, "tasks.json");

export function initTasksFileIfMissing(): void {
  const data = readJsonSync(TASKS_FILE);
  if (data === null) {
    saveTasks([]);
  }
}

export function getTasks(): Task[] {
  const rawData = readJsonSync<any[]>(TASKS_FILE, []);
  if (!rawData || !Array.isArray(rawData)) return [];
  return rawData.map((task) => Task.fromJson(task));
}

export function saveTasks(tasks: Task[]): void {
  writeJsonSync(TASKS_FILE, tasks);
}

export function findTask(id: string): Task | undefined {
  return getTasks().find((task) => task.id === id);
}

export function addTask(task: Task): void {
  const tasks = getTasks();
  tasks.push(task);
  saveTasks(tasks);
}

export function deleteTask(id: string): boolean {
  const tasks = getTasks();
  const filtered = tasks.filter((task) => task.id !== id);
  if (filtered.length === tasks.length) {
    return false;
  }
  saveTasks(filtered);
  return true;
}

export function toggleTask(id: string): Task | null {
  const tasks = getTasks();
  const idx = tasks.findIndex((task) => task.id === id);
  if (idx === -1) {
    return null;
  }
  tasks[idx].enabled = !tasks[idx].enabled;
  saveTasks(tasks);
  return tasks[idx];
}
