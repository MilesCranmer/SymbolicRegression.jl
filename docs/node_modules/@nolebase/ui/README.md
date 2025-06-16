# `@nolebase/ui`

A collection of Vue components Nolebase uses.

> [!CAUTION]
>
> This package is in Alpha stage.
>
> This package is still in the Alpha stage, and it is not recommended to use it in production. The API may change in the future, and there may be bugs in the current version. Please use it with caution.

> [!IMPORTANT]
>
> Before install
>
> Currently `@nolebase/ui` is still under development, and will be used by other [Nolebase Integrations](https://nolebase-integrations.ayaka.io) components now. There are a few configurations that needed to be configured if you would ever want to install `@nolebase/ui` as one of your dependencies:
>
> #### 1. Additional configurations for Vite
>
> ##### 1.1 For users who imported `<NuLazyTeleportRiveCanvas />` component
>
> Since `<NuLazyTeleportRiveCanvas />` depends on `@rive-app/canvas`. If you also use Vite as your bundler, you will need to add the following configurations to your `vite.config.ts` file like this:
>
> ```typescript
> export default defineConfig(() => {
>   return {
>     optimizeDeps: {
>       include: [
>         // Add this line to your vite.config.ts
>         '@nolebase/ui-rive-canvas > @rive-app/canvas',
>       ],
>     },
>   }
> })
> ```
>
> For more information about why configure this, please refer to the [Dep Optimization Options | Vite](https://vitejs.dev/config/dep-optimization-options.html#optimizedeps-exclude) documentation.
>
> ##### 1.2 For users who imported VitePress related components
>
> If you are using VitePress, you will need to add the following configurations to your `vite.config.ts` file like this:
>
> ```typescript
> export default defineConfig(() => {
>   return {
>     ssr: {
>       noExternal: [
>         // Add this line to your vite.config.ts
>         '@nolebase/ui',
>       ],
>     },
>   }
> })
> ```
>
> For more information about why configure this, please refer to the [Server-Side Rendering | Vite](https://vitejs.dev/guide/ssr.html#ssr-externals) documentation.

## Install

### Npm

```shell
npm i @nolebase/ui -D
```

### Yarn

```shell
yarn add @nolebase/ui -D
```

### Pnpm

```shell
pnpm add @nolebase/ui -D
```

## Documentation

Please refer to [UI Components](https://nolebase-integrations.ayaka.io/pages/en/ui/) for more information.
