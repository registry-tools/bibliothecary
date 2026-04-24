# Settings (.yarnrc.yml)

Yarnrc files (named this way because they must be called `.yarnrc.yml`) are the one place where you'll be able to configure Yarn's internal settings. While Yarn will automatically find them in the parent directories, they should usually be kept at the root of your project (often your repository). **Starting from the v2, they must be written in valid Yaml and have the right extension** (simply calling your file `.yarnrc` won't do).

Environment variable expansion is available in the following forms:

- `${NAME}` expands to the value of the variable `NAME` and throws if it is not set
- `${NAME:-fallback}` expands to the value of `NAME` if it is set and not empty, or the expansion of `fallback` otherwise
- `${NAME-fallback}` expands to the value of `NAME` if it is set, or the expansion of `fallback` otherwise

`$`, `\`, and `}` can be escaped by preceding them with a `\`. All other `\` s and unmatched `}` are treated literally. Unclosed expansions and unescaped `${` sequences that are not recognized as an expansion throw errors.

Finally, note that most settings can also be defined through environment variables (at least for the simpler ones; arrays and objects aren't supported yet). To do this, just prefix the names and write them in snake case: `YARN_CACHE_FOLDER` will set the cache folder (such values will overwrite any that might have been defined in the RC files - use them sparingly).

### cacheFolder

Path where the downloaded packages are stored on your system.

They'll be normalized, compressed, and saved under the form of zip archives with standardized names. The cache is deemed to be relatively safe to be shared by multiple projects, even when multiple Yarn instances run at the same time on different projects. For setting a global cache folder, you should use `enableGlobalCache` instead.

[cacheFolder](#cacheFolder): "./.yarn/cache",

### cacheMigrationMode

Behavior that Yarn should follow when it detects that a cache entry is outdated.

Whether or not a cache entry is outdated depends on whether it has been built and checksumed by an earlier release of Yarn, or under a different compression settings. Possible behaviors are:

- If `required-only`, it'll keep using the file as-is, unless the version that generated it was decidedly too old.
- If `match-spec`, it'll also rebuild the file if the compression level has changed.
- If `always` (the default), it'll always regenerate the cache files so they use the current cache version.

[cacheMigrationMode](#cacheMigrationMode): "required-only" | "match-spec" | "always",

### changesetBaseRefs

List of git refs against which Yarn will compare your branch when it needs to detect changes.

Supports git branches, tags, and commits. The default configuration will compare against master, origin/master, upstream/master, main, origin/main, and upstream/main.

[changesetBaseRefs](#changesetBaseRefs): \[

"master",

"origin/master",

"upstream/master",

"main",

"origin/main",

"upstream/main",

\],

### changesetIgnorePatterns

Array of file glob patterns that will be excluded from change detection.

Files matching the following patterns (in terms of relative paths compared to the root of the project) will be ignored by every command checking whether files changed compared to the base ref (this include both `yarn version check` and `yarn workspaces foreach --since`).

[changesetIgnorePatterns](#changesetIgnorePatterns): \[

"\*\*/\*.test.{js,ts}",

\],

### checksumBehavior

Behavior that Yarn should follow when it detects that a cache entry has a different checksum than expected.

Possible behaviors are:

- If `throw` (the default), Yarn will throw an exception.
- If `update`, the lockfile will be updated to match the cached checksum.
- If `reset`, the cache entry will be purged and fetched anew.
- If `ignore`, nothing will happen, Yarn will skip the check.

[checksumBehavior](#checksumBehavior): "throw" | "update" | "ignore" | "reset",

### cloneConcurrency

Amount of `git clone` operations that Yarn will run at the same time.

We by default limit it to 2 concurrent clone operations.

[cloneConcurrency](#cloneConcurrency): 2,

### approvedGitRepositories

Array of git repository URL glob patterns that are allowed to be fetched.

When set, Yarn will block any git dependency whose normalized repository URL doesn't match one of these patterns. GitHub repositories must be explicitly approved.

[approvedGitRepositories](#approvedGitRepositories): \[

"https://github.com/yarnpkg/\*",

"ssh://git@github.com/yarnpkg/\*",

\],

### compressionLevel

Compression level employed for zip archives

Possible values go from `0` ("no compression, faster") to `9` ("heavy compression, slower"). The value `mixed` is a variant of `9` where files are stored uncompressed if the gzip overhead would exceed the size gain.

The default is `0`, which tends to be significantly faster to install. Projects using zero-installs are advised to keep it this way, as experiments showed that Git stores uncompressed package archives more efficiently than gzip-compressed ones.

[compressionLevel](#compressionLevel): 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | "mixed",

### constraintsPath

Path of the constraints file.

This only matters for Prolog constraints, which are being deprecated. JavaScript constraints will always be read from the `yarn.config.cjs` file.

[constraintsPath](#constraintsPath): "./constraints.pro",

### defaultLanguageName

Default language mode that should be used when a package doesn't offer any insight.

This is an internal configuration setting that shouldn't be touched unless you really know what you're doing.

[defaultLanguageName](#defaultLanguageName): "node",

### defaultProtocol

Default protocol that should be used when a dependency range is a pure semver range.

This is an internal configuration setting that shouldn't be touched unless you really know what you're doing.

[defaultProtocol](#defaultProtocol): "npm:",

### defaultSemverRangePrefix

Default prefix used in semver ranges created by `yarn add` and similar commands.

Possible values are `"^"` (the default), `"~"` or `""`.

[defaultSemverRangePrefix](#defaultSemverRangePrefix): "^" | "~" | "",

### deferredVersionFolder

Folder where the versioning files are stored.

[deferredVersionFolder](#deferredVersionFolder): "./.yarn/versions",

### enableColors

Define whether colors are allowed on the standard output.

The default is to check the terminal capabilities, but you can manually override it to either `true` or `false`.

[enableColors](#enableColors): true,

### enableConstraintsChecks

Define whether constraints should run on every install.

If true, Yarn will run your constraints right after finishing its installs. This may help decrease the feedback loop delay by catching errors long before your CI would even report them.

[enableConstraintsChecks](#enableConstraintsChecks): true,

### enableGlobalCache

Define whether the cache should be shared between all local projects.

If true (the default), Yarn will store the cache files into a folder located within `globalFolder` instead of respecting `cacheFolder`.

[enableGlobalCache](#enableGlobalCache): true,

### enableHardenedMode

Define whether Yarn should attempt to check for malicious changes.

If true, Yarn will query the remote registries to validate that the lockfile content matches the remote information. These checks make installs slower, so you should only run them on branches managed by users outside your circle of trust.

Yarn will automatically enable the hardened mode on GitHub pull requests from public repository. Should you want to disable it, explicitly set it to `false` in your yarnrc file.

[enableHardenedMode](#enableHardenedMode): true,

### enableHyperlinks

Define whether hyperlinks are allowed on the standard output.

The default is to check the terminal capabilities, but you can manually override it to either `true` or `false`.

[enableHyperlinks](#enableHyperlinks): true,

### enableImmutableCache

Define whether to allow adding/removing files from the cache or not.

If true, Yarn will refuse to change the cache in any way, whether it would add files or remove them, and will abort installs instead of letting that happen.

[enableImmutableCache](#enableImmutableCache): false,

### enableImmutableInstalls

Define whether to allow adding/removing entries from the lockfile or not.

If true (the default on CI), Yarn will refuse to change the lockfile in any way, whether it would add new entries or remove them. Other files can be added to the checklist via the `immutablePatterns` setting.

[enableImmutableInstalls](#enableImmutableInstalls): false,

### enableInlineBuilds

Define whether to print the build output directly within the terminal or not.

If true (the default on CI environments), Yarn will print the build output directly within the terminal instead of buffering it in an external log file. Note that by default Yarn will attempt to use collapsible terminal sequences on supporting CI providers to make the output more legible.

[enableInlineBuilds](#enableInlineBuilds): false,

### enableInlineHunks

Define whether to print patch hunks directly within the terminal or not.

If true, Yarn will print any patch sections (hunks) that could not be applied successfully to the terminal.

[enableInlineHunks](#enableInlineHunks): false,

### enableMessageNames

Define whether to prepend a message name before each printed line or not.

If true, Yarn will prefix most messages with codes suitable for search engines, with hyperlink support if your terminal allows it.

[enableMessageNames](#enableMessageNames): true,

### enableMirror

Define whether to mirror local cache entries into the global cache or not.

If true (the default), Yarn will use the global folder as indirection between the network and the actual cache. This is only useful if `enableGlobalCache` is explicitly set to `false`, as otherwise the cache entries are persisted to the global cache no matter what.

[enableMirror](#enableMirror): true,

### enableNetwork

Define whether remote network requests are allowed or not.

If false, Yarn will never make any request to the network by itself, and will throw an exception rather than let it happen. It's a very useful setting for CI, which typically want to make sure they aren't loading their dependencies from the network by mistake.

[enableNetwork](#enableNetwork): true,

### enableOfflineMode

Define whether Yarn should exclusively read package metadata from its cache

If true, Yarn will replace any network requests by reads from its local caches - even if they contain old information. This can be useful when performing local work on environments without network access (trains, planes,...), as you can at least leverage the packages you installed on the same machine in the past.

Since this setting will lead to stale data being used, it's recommended to set it for the current session as an environment variable (by running `export YARN_ENABLE_OFFLINE_MODE=1` in your terminal) rather than by adding it to your `.yarnrc.yml` file.

[enableOfflineMode](#enableOfflineMode): false,

### enableProgressBars

Define whether animated progress bars should be shown or not.

If true (the default outside of CI environments), Yarn will show progress bars for long-running events.

[enableProgressBars](#enableProgressBars): true,

### enableScripts

Define whether to run postinstall scripts or not.

If false (the default), Yarn will not execute the `postinstall` scripts from third-party packages when installing the project (workspaces will still see their postinstall scripts evaluated, as they're assumed to be safe if you're running an install within them).

Note that you also have the ability to disable scripts on a per-package basis using `dependenciesMeta`, or to re-enable a specific script by combining `enableScripts` and `dependenciesMeta`.

[enableScripts](#enableScripts): false,

### enableStrictSsl

Define whether SSL errors should fail requests or not.

If false, SSL certificate errors will be ignored

[enableStrictSsl](#enableStrictSsl): true,

### enableTelemetry

Define whether anonymous telemetry data should be sent or not.

If true (the default outside of CI environments), Yarn will periodically send anonymous data to our servers tracking some usage information such as the number of dependencies in your project, how many installs you ran, etc.

Consult the [Telemetry](https://yarnpkg.com/advanced/telemetry) page for more details about this process.

[enableTelemetry](#enableTelemetry): true,

### enableTimers

Define whether to print the time spent running each sub-step or not.

If false, Yarn will not print the time spent running each sub-step when running various commands. This is only needed for testing purposes, when you want each execution to have exactly the same output as the previous ones.

[enableTimers](#enableTimers): true,

### enableTransparentWorkspaces

Define whether pure semver ranges should allow workspace resolution or not.

If false, Yarn won't link workspaces just because their versions happen to match a semver range. Disabling this setting will require all workspaces to reference one another using the explicit `workspace:` protocol.

This setting is usually only needed when your project needs to use the published version in order to build the new one (that's for example what happens with Babel, which depends on the latest stable release to build the future ones).

[enableTransparentWorkspaces](#enableTransparentWorkspaces): true,

### globalFolder

Path where all files global to the system will be stored.

Various files we be stored there: global cache, metadata cache,...

[globalFolder](#globalFolder): "${HOME}/.yarn/berry",

### httpProxy

Proxy to use when making an HTTP request.

[httpProxy](#httpProxy): "http://proxy:4040",

### httpRetry

Amount of time to wait in seconds before retrying a failed HTTP request.

[httpRetry](#httpRetry): 3,

### httpTimeout

Amount of time to wait before cancelling pending HTTP requests.

[httpTimeout](#httpTimeout): "1m",

### httpsCaFilePath

Path to a file containing one or multiple Certificate Authority signing certificates.

[httpsCaFilePath](#httpsCaFilePath): "./exampleCA.pem",

### httpsCertFilePath

Path to a file containing a certificate chain in PEM format.

[httpsCertFilePath](#httpsCertFilePath): "./exampleCert.pem",

### httpsKeyFilePath

Path to a file containing a private key in PEM format.

[httpsKeyFilePath](#httpsKeyFilePath): "./exampleKey.pem",

### httpsProxy

Define a proxy to use when making an HTTPS request.

[httpsProxy](#httpsProxy): "http://proxy:4040",

### ignorePath

Define whether `yarnPath` should be respected or not.

If true, whatever Yarn version is being executed will keep running rather than looking at the value of `yarnPath` to decide.

[ignorePath](#ignorePath): false,

### immutablePatterns

Array of file patterns whose content won't be allowed to change if `enableImmutableInstalls` is set.

[immutablePatterns](#immutablePatterns): \[

"\*\*/.pnp.\*",

\],

### initScope

Scope used when creating packages via the `init` command.

[initScope](#initScope): "yarnpkg",

### injectEnvironmentFiles

Array of.env files which will get injected into any subprocess spawned by Yarn.

By default Yarn will automatically inject the variables stored in the `.env.yarn` file, but you can use this setting to change this behavior.

Note that adding a question mark at the end of the path will silence the error Yarn would throw should the file be missing, which may come in handy when declaring local configuration files.

[injectEnvironmentFiles](#injectEnvironmentFiles): \[

".my-env",

".my-local-env?",

\],

### installStatePath

Path where the install state will be persisted.

The install state file contains a bunch of cached information about your project. It's only used for optimization purposes, and will be recreated if missing (you don't need to add it to Git).

[installStatePath](#installStatePath): "./.yarn/install-state.gz",

### logFilters

Alter the log levels for emitted messages.

This can be used to hide specific messages, or instead make them more prominent. Rules defined there accept filtering messages by either name or raw content.

[logFilters](#logFilters): \[{

### logFilters.code

Match all messages with the given code.

[code](#logFilters.code): "YN0006",

### logFilters.level

New log level to apply to the matching messages. Use `discard` if you wish to hide those messages altogether.

[level](#logFilters.level): "info" | "warning" | "error" | "discard",

}, {

### logFilters.text

Match messages whose content is strictly equal to the given text.

In case a message matches both `code` -based and `text` -based filters, the `text` -based ones will take precedence over the `code` -based ones.

[text](#logFilters.text): "lorem-ipsum@npm:1.2.3 lists build scripts, but its build has been explicitly disabled through configuration",

### logFilters.level

New log level to apply to the matching messages. Use `discard` if you wish to hide those messages altogether.

[level](#logFilters.level): "info" | "warning" | "error" | "discard",

}, {

### logFilters.pattern

Match messages whose content match the given glob pattern.

In case a message matches both `pattern` -based and `code` -based filters, the `pattern` -based ones will take precedence over the other ones. Patterns can be overridden on a case-by-case basis by using the `text` filter, which has precedence over `pattern`.

[pattern](#logFilters.pattern): "lorem-ipsum@\* lists build scripts, but its build has been explicitly disabled through configuration",

### logFilters.level

New log level to apply to the matching messages. Use `discard` if you wish to hide those messages altogether.

[level](#logFilters.level): "info" | "warning" | "error" | "discard",

}\],

### networkConcurrency

Amount of HTTP requests that are allowed to run at the same time.

We default to 50 concurrent requests, but it may be required to limit it even more when working behind proxies that can't handle large amounts of traffic.

[networkConcurrency](#networkConcurrency): 50,

### nmHoistingLimits

Highest point where packages can be hoisted.

Replacement of the former `nohoist` setting. Possible values are:

- If `none` (the default), packages are hoisted as per the usual rules.
- If `workspaces`, packages won't be hoisted past the workspace that depends on them.
- If `dependencies`, transitive dependencies also won't be hoisted past your direct dependencies.

This setting can be overridden on a per-workspace basis using the `installConfig.hoistingLimits` field.

[nmHoistingLimits](#nmHoistingLimits): "workspaces" | "dependencies" | "none",

### nmSelfReferences

Define whether workspaces are allowed to require themselves.

If false, Yarn won't create self-referencing symlinks when using `nodeLinker: node-modules`. This setting can be overridden on a per-workspace basis using the `installConfig.selfReferences` field.

[nmSelfReferences](#nmSelfReferences): true,

### nmMode

Define how to copy files to their target destination.

Possible values are:

- If `classic`, regular copy or clone operations are performed.
- If `hardlinks-global`, hardlinks to a global content-addressable store will be used.
- If `hardlinks-local`, hardlinks will only be created between similar packages from the same project.

For compatibility with the ecosystem, the default is `classic`.

[nmMode](#nmMode): "classic" | "hardlinks-local" | "hardlinks-global",

### nodeLinker

Define how Node packages should be installed.

Yarn supports three ways to install your project's dependencies, based on the `nodeLinker` setting. Possible values are:

- If `pnp`, a single Node.js loader file will be generated.
- If `pnpm`, a `node-modules` will be created using symlinks and hardlinks to a global content-addressable store.
- If `node-modules`, a regular `node_modules` folder just like in Yarn Classic or npm will be created.

[nodeLinker](#nodeLinker): "pnp",

### npmMinimalAgeGate

Minimum age of a package version according to the publish date on the npm registry to be considered for installation.

If a package version is newer than the minimal age gate, it will not be considered for installation. This can be used to reduce the likelihood of installing compromised packages, or to avoid relying on packages that could still be unpublished (e.g. the npm registry has specific rules for packages less than 3 days old).

[npmMinimalAgeGate](#npmMinimalAgeGate): "3d",

### npmPreapprovedPackages

Array of package descriptors or package name glob patterns to exclude from all of the package gates.

If a package descriptor or name matches the specified pattern, it will not be considered when evaluating any of the package gates.

[npmPreapprovedPackages](#npmPreapprovedPackages): \[\],

### pnpmStoreFolder

Path where the pnpm store will be stored

By default, the store is stored in the `node_modules/.store` of the project. Sometimes in CI scenario's it is convenient to store this in a different location so it can be cached and reused.

[pnpmStoreFolder](#pnpmStoreFolder): ".cache/.store",

### winLinkType

Define whether to use junctions or symlinks when creating links on Windows.

Possible values are:

- If `junctions`, Yarn will use Windows junctions when linking workspaces into `node_modules` directories, which are always absolute paths.
- If `symlinks`, Yarn will use symlinks, which will use relative paths, and is consistent with Yarn's behavior on non-Windows platforms.

Symlinks are preferred, but they require the Windows user running Yarn to have the `create symbolic links` privilege. As a result, we default to using junctions instead.

[winLinkType](#winLinkType): "junctions" | "symlinks",

### npmAlwaysAuth

Define whether to always send authentication credentials when querying the npm registry.

If true, authentication credentials will always be sent when sending requests to the registries. This shouldn't be needed unless you configured the registry to reference a private npm mirror.

[npmAlwaysAuth](#npmAlwaysAuth): false,

### npmAuditRegistry

Define the registry to use when auditing dependencies.

If not explicitly set, the value of `npmRegistryServer` will be used.

[npmAuditRegistry](#npmAuditRegistry): "https://registry.npmjs.org",

### npmAuthIdent

Define the authentication credentials to use by default when accessing your registries.

Replacement of the former `_auth` setting. Because it requires storing unencrypted values in your configuration, `npmAuthToken` should be preferred when possible.

[npmAuthIdent](#npmAuthIdent): "username:password",

### npmAuthToken

Define the authentication token to use by default when accessing your registries.

Replacement of the former `_authToken` settings. If you're using `npmScopes` to define multiple registries, the `npmRegistries` dictionary allows you to override these credentials on a per-registry basis.

[npmAuthToken](#npmAuthToken): "ffffffff-ffff-ffff-ffff-ffffffffffff",

### npmPublishAccess

Define the default access to use when publishing packages to the npm registry.

Valid values are `public` and `restricted`, but `restricted` usually requires to register for a paid plan (this is up to the registry you use). Can be overridden on a per-package basis using the [`publishConfig.access`](https://yarnpkg.com/configuration/manifest#publishConfig.access) field.

[npmPublishAccess](#npmPublishAccess): "public" | "restricted",

### npmPublishProvenance

Define whether to attach a provenance statement when publishing packages to the npm registry.

If true, Yarn will generate and publish the provenance information when publishing packages. Can be overridden on a per-package basis using the [`publishConfig.provenance`](https://yarnpkg.com/configuration/manifest#publishConfig.provenance) field.

[npmPublishProvenance](#npmPublishProvenance): false,

### npmAuditExcludePackages

Array of package name glob patterns to exclude from `yarn npm audit`.

[npmAuditExcludePackages](#npmAuditExcludePackages): \[\],

### npmAuditIgnoreAdvisories

Array of advisory ID glob patterns to ignore from `yarn npm audit` results.

[npmAuditIgnoreAdvisories](#npmAuditIgnoreAdvisories): \[\],

### npmPublishRegistry

Define the registry to use when pushing packages.

If not explicitly set, the value of `npmRegistryServer` will be used. Overridden by `publishConfig.registry`.

[npmPublishRegistry](#npmPublishRegistry): "https://npm.pkg.github.com",

### npmRegistryServer

Define the registry to use when fetching packages.

Should you want to define different registries for different scopes, see `npmScopes`. To define the authentication scheme for your servers, see `npmAuthToken`. The url must use HTTPS by default, but this can be changed by adding it to the `unsafeHttpWhitelist`.

[npmRegistryServer](#npmRegistryServer): "https://registry.yarnpkg.com",

### packageExtensions

Extend the package definitions of your dependencies; useful to fix third-party issues.

Some packages may have been specified incorrectly with regard to their dependencies - for example with one dependency being missing, causing Yarn to refuse it the access. The `packageExtensions` fields offer a way to extend the existing package definitions with additional information. If you use it, consider sending a PR upstream and contributing your extension to the [`plugin-compat` database](https://github.com/yarnpkg/berry/blob/master/packages/yarnpkg-extensions/sources/index.ts).

Note: This field is made to add dependencies; if you need to rewrite existing ones, prefer the `resolutions` field instead.

[packageExtensions](#packageExtensions): {

[webpack@\*](#packageExtensions): {

[dependencies](#packageExtensions): {

[lodash](#packageExtensions): "^4.15.0",

},

[peerDependencies](#packageExtensions): {

[webpack-cli](#packageExtensions): "\*",

},

[peerDependenciesMeta](#packageExtensions): {

[webpack-cli](#packageExtensions): {

[optional](#packageExtensions): true,

},

},

},

},

### patchFolder

Folder where patch files will be written to.

[patchFolder](#patchFolder): "./.yarn/patches",

### pnpEnableEsmLoader

Define whether to generate a Node.js ESM loader or not.

If true, Yarn will generate an experimental ESM loader (`.pnp.loader.mjs`) on top of the CJS one.

[pnpEnableEsmLoader](#pnpEnableEsmLoader): false,

### pnpEnableInlining

Define whether to store the PnP data in the generated file or not.

If false, Yarn will generate an additional `.pnp.data.json` file.

[pnpEnableInlining](#pnpEnableInlining): true,

### pnpFallbackMode

Define whether to allow packages to rely on the builtin PnP fallback mechanism.

Possible values are:

- If `all`, all packages can access dependencies made available in the fallback.
- If `dependencies-only` (the default), dependencies will have access to them but not your workspaces.
- If `none`, no packages will have access to them.

[pnpFallbackMode](#pnpFallbackMode): "none" | "dependencies-only" | "all",

### pnpIgnorePatterns

Array of file glob patterns that should be forced to use the default CommonJS resolution.

Files matching those locations will not be covered by PnP and will use the regular Node.js resolution algorithm. Typically only needed if you have subprojects that aren't yet part of your workspace tree.

[pnpIgnorePatterns](#pnpIgnorePatterns): \[

"./subdir/\*",

\],

### pnpMode

Define whether to attempt to simulate traditional `node_modules` hoisting.

Possible values are:

- If `strict` (the default), modules won't be allowed to require packages they don't explicitly list in their own dependencies.
- If `loose`, packages will be allowed to access any other package that would have been hoisted to the top-level under 1.x installs.

Note that, even in loose mode, hoisted require calls are unsafe and should be discouraged.

[pnpMode](#pnpMode): "strict" | "loose",

### pnpShebang

String prepended to the generated PnP loader.

[pnpShebang](#pnpShebang): "#!/usr/bin/env node",

### pnpUnpluggedFolder

Path where unplugged packages are stored.

While Yarn attempts to reference and load packages directly from their zip archives, it may not always be possible. In those cases, Yarn will extract the files to the unplugged folder.

[pnpUnpluggedFolder](#pnpUnpluggedFolder): "./.yarn/unplugged",

### preferDeferredVersions

Define whether to use deferred versioning by default or not.

If true, deferred versioning by default when running the `yarn version` family of commands.

[preferDeferredVersions](#preferDeferredVersions): false,

### preferInteractive

Define whether to use interactive prompts by default or not.

If true, Yarn will ask for your guidance when some actions would be improved by being disambiguated. Enabling this setting also unlocks some features (for example the `yarn add` command will suggest to reuse the same dependencies as other workspaces if pertinent).

[preferInteractive](#preferInteractive): false,

### preferReuse

Define whether to reuse most common dependency ranges or not when adding dependencies to a package.

If true, `yarn add` will attempt to reuse the most common dependency range in other workspaces.

[preferReuse](#preferReuse): false,

### preferTruncatedLines

Define whether to truncate lines that would go beyond the size of the terminal or not.

If true, Yarn will truncate lines that would go beyond the size of the terminal. If progress bars are disabled, lines will never be truncated.

[preferTruncatedLines](#preferTruncatedLines): false,

### progressBarStyle

Style of progress bar to use.

[progressBarStyle](#progressBarStyle): "patrick" | "simba" | "jack" | "hogsfather" | "default",

### supportedArchitectures

Systems for which Yarn should install packages.

[supportedArchitectures](#supportedArchitectures): {

### supportedArchitectures.os

List of operating systems to cover.

[os](#supportedArchitectures.os): \[

"current",

"darwin",

"linux",

"win32",

\],

### supportedArchitectures.cpu

List of CPU architectures to cover.

See https://nodejs.org/docs/latest/api/process.html#processarch for the architectures supported by Node.js

[cpu](#supportedArchitectures.cpu): \[

"current",

"x64",

"ia32",

"arm64",

\],

### supportedArchitectures.libc

The list of standard C libraries to cover.

[libc](#supportedArchitectures.libc): \[

"current",

"glibc",

"musl",

\],

},

### taskPoolConcurrency

Maximal amount of concurrent heavy task processing.

We default to the platform parallelism, but for some CI, `os.cpus` may not report accurate values and may overwhelm their containers.

[taskPoolConcurrency](#taskPoolConcurrency): "os.availableParallelism()",

### taskPoolMode

Execution strategy for heavy tasks.

By default will use workers when performing heavy tasks, such as converting tgz files to zip. This setting can be used to disable workers and use a regular in-thread async processing.

[taskPoolMode](#taskPoolMode): "async" | "workers",

### telemetryInterval

Define the minimal amount of time between two telemetry events.

By default we only send one request per week, making it impossible for us to track your usage with a lower granularity.

[telemetryInterval](#telemetryInterval): "7d",

### telemetryUserId

User-defined unique ID to send along with telemetry events.

The default settings never assign unique IDs to anyone, so we have no way to know which data originates from which project. This setting can be used to force a user ID to be sent to our telemetry server.

Frankly, it's only useful in some very specific use cases. For example, we use it on the Yarn repository in order to exclude our own usage from the public dashboards (since we run Yarn far more often here than anywhere else, the resulting data would be biased).

[telemetryUserId](#telemetryUserId): "yarnpkg/berry",

### tsEnableAutoTypes

Define whether to automatically install @types dependencies.

If true, Yarn will automatically add `@types` dependencies when running `yarn add` with packages that don't provide their own typings (as reported by the Algolia npm database). This behavior is enabled by default if you have a tsconfig.json file at the root of your project, or in your current workspace.

[tsEnableAutoTypes](#tsEnableAutoTypes): true,

### unsafeHttpWhitelist

Array of hostname glob patterns for which using the HTTP protocol is allowed.

[unsafeHttpWhitelist](#unsafeHttpWhitelist): \[

"\*.example.org",

"example.org",

\],

### virtualFolder

Path where virtual packages will be stored.

Due to a particularity in how Yarn installs packages which list peer dependencies, some packages will be mapped to multiple virtual directories that don't actually exist on the filesystem. This settings tells Yarn where to put them. Note that the folder name *must* be `__virtual__`.

[virtualFolder](#virtualFolder): "./.yarn/\_\_virtual\_\_",

### yarnPath

Path of a Yarn binary to use instead of the global one.

This binary will be executed instead of any other (including the global one) for any command run within the directory covered by the rc file. If the file extension ends with `.js` it will be required, and will be spawned in any other case.

The `yarnPath` setting used to be the preferred way to install Yarn within a project, but we now recommend to use [Corepack](https://nodejs.org/api/corepack.html) in most cases.

[yarnPath](#yarnPath): "./scripts/yarn-2.0.0-rc001.js",