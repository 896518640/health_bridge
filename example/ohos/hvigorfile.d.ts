declare module '@ohos/hvigor-ohos-plugin' {
  export const appTasks: any;
  export const hapTasks: any;
  export const hspTasks: any;
}

declare module 'flutter-hvigor-plugin' {
  export function flutterHvigorPlugin(path: string): any;
  export function injectNativeModules(dirname: string, parentDir: string): void;
}
