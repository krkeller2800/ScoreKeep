# ScoreKeep URL Inventory

Scope: inspected the ScoreKeep project for hard-coded KomoKode URLs, remote paths, filenames, JSON endpoints, download logic, and URL-building code. Production code was not modified.

## Website Compatibility Contracts

Released versions of ScoreKeep depend on a small set of public KomoKode website resources. These paths are app-facing contracts, separate from the website's visual structure and navigation.

### Team Manifest

Permanent public endpoint: `https://komakode.com/Teams/index.json`

Released versions of ScoreKeep use this endpoint to obtain the MLB roster-download manifest. The endpoint path and JSON schema are compatibility contracts: the manifest currently contains divisions and team entries, and each team entry contains a downloadable URL.

Existing released apps may continue requesting this exact path. Do not move or rename the endpoint without maintaining compatibility through a stable legacy path, redirect, or equivalent Cloudflare routing. A website redesign must not silently replace this JSON response with HTML.

### Messages Manifest

Permanent public endpoint: `https://komakode.com/Teams/message.json`

Released versions of ScoreKeep use this endpoint for ScoreKeep messages. Its path and expected JSON shape must remain compatible, and it must continue returning JSON rather than an HTML page. Website navigation changes must not interfere with this endpoint.

### Team Roster Files

Permanent file convention: `https://komakode.com/Teams/<Team>.ScoreKeep_Players`

The `.ScoreKeep_Players` filename extension is part of the import contract. Existing manifest URLs and released apps may depend on exact roster URLs, so these files must remain downloadable without authentication. The server should continue serving them as downloadable files rather than redirecting them to the website home page.

Deploy replacement files before changing manifest URLs. Keep old URLs available whenever practical, or preserve them with stable redirects or equivalent Cloudflare routing.

### Website Fallback Behavior

The KomoKode website currently preserves its historical behavior for unknown human-facing paths: a mistyped or nonexistent normal website path may display the home page with HTTP 200. This behavior is intentionally accepted for the human-facing site.

Do not let that fallback mask failures for ScoreKeep compatibility resources. `/Teams/index.json`, `/Teams/message.json`, and `.ScoreKeep_Players` URLs must still return their actual JSON or file content. Future maintainers should test the exact resource URL and verify status, content type, and body rather than relying only on whether a browser displays a page.

### Website Redesign History

The KomoKode website was redesigned and deployed from the `main` branch. The ScoreKeep endpoints were deliberately preserved as compatibility resources.

Released ScoreKeep production checks passed after the redesign: messages loaded, the MLB roster list loaded, at least one roster downloaded, and the downloaded roster imported successfully. The website's visual structure is separate from these app-facing contracts.

## Summary

- Current remote roster discovery is hard-coded to `https://komakode.com/Teams/index.json`.
- Current remote announcements are hard-coded to `https://komakode.com/Teams/message.json`.
- Team file download URLs are not assembled from a local base URL in current code; they come from each `teams[].url` value in `index.json`.
- Team roster downloads use the `.ScoreKeep_Players` import extension, which is part of the app compatibility contract.
- `Manual.pdf` is bundled and loaded locally, not fetched remotely.
- Privacy policy is a hard-coded web URL.
- No `media.komakode.com` references were found in app source.
- No standalone hard-coded `https://komakode.com` home-page link was found; the domain appears only as part of specific endpoint/link strings and comments.
- Legacy/older download parsing still exists in `DownloadFiles.fetchFileList(from:)`, but no active caller was found.

## Inventory

| Reference | Source file | Line | Function or type | Purpose | Hard-coded or constructed | App update required to change? | Older released versions keep old URL? | Recommended compatibility approach |
|---|---|---:|---|---|---|---|---|---|
| `https://komakode.com/Teams/index.json` | `ScoreKeep/ScoreKeep/Sharing Data/ShareContentView.swift` | 607 | `ShareContentView.getFileNames()` | Primary MLB/team roster index endpoint. Fetches available teams, last-updated metadata, and direct per-team download URLs. | Hard-coded full URL literal. | Yes, for changing the index endpoint itself in installed app code. | Yes. Any released build with this literal will continue requesting this exact endpoint. | Keep this URL permanently available. Treat it as a stable manifest. If moving infrastructure, redirect this path or serve a compatibility manifest from it. |
| `Teams/index.json` | `ScoreKeep/ScoreKeep/Sharing Data/DownloadFiles.swift` | 12 | `DownloadFiles` | Comment documents the expected JSON model source for the team index. | Hard-coded path in comment only. | No runtime effect. | Not applicable. | Keep comments aligned with the actual production endpoint when production code is next edited. |
| `updated` field in `index.json` | `ScoreKeep/ScoreKeep/Sharing Data/ShareContentView.swift` | 630 | `ShareContentView.fetchIndexUpdated(from:)` | Reads the index metadata date and displays `Updated on: MM/dd/yyyy`. Uses the same URL passed from `getFileNames()`. | Constructed by reuse of the `indexURL` URL object from line 607. | Same as `index.json`: app update only if the endpoint changes in code. Server-side content changes need no app update if schema remains compatible. | Yes, older builds continue fetching the hard-coded `index.json`. | Preserve the optional `updated` field as an ISO-8601 date. Do not make the field required for older app behavior. |
| `teams[].url` values inside `index.json` | `ScoreKeep/ScoreKeep/Sharing Data/DownloadFiles.swift` | 21-23 | `DownloadFiles.IndexTeam` | Defines the remote index schema: every team entry supplies `name` and direct `url`. | Constructed remotely by server-provided JSON content. | No app update required to change individual team file URLs if `index.json` remains at the same endpoint and schema-compatible. | Older current-schema versions will follow whatever URL is served in `index.json`. Much older versions may differ if they predate the JSON index. | Use `index.json` as the indirection layer. Keep old team files live or put redirects in place. Prefer absolute HTTPS URLs in `url` values. |
| Team name to URL map from `index.json` | `ScoreKeep/ScoreKeep/Sharing Data/ShareContentView.swift` | 621-624 | `ShareContentView.getFileNames()` | Stores picker names and maps selected team names to direct download URLs from the remote index. | Constructed from remote `index.json` content. | No app update for roster URL changes; yes for schema/name behavior changes. | Yes, released versions with this logic continue using the old index endpoint but can receive new team URLs from it. | Keep team `name` values stable enough for deep-link prefill and user selection. Add new fields only as optional. |
| Selected team file URL | `ScoreKeep/ScoreKeep/Sharing Data/ShareContentView.swift` | 298-305 | `ShareContentView.body` `.onChange(of: down)` | Resolves selected team with `teamURLMap[down]`, then downloads the direct URL to a local `.ScoreKeep_Players` file. | Constructed from remote `index.json` plus local selected team name. | No app update for changing remote file locations if index entries are updated. | Yes, older current-schema versions follow the URLs in their fetched index. | Maintain direct URLs in `index.json`; if changing host/path, update the manifest first and keep old URLs or HTTP redirects for cached/shared references. |
| Percent-encoded team download URL | `ScoreKeep/ScoreKeep/Sharing Data/DownloadFiles.swift` | 109-118 | `DownloadFiles.downloadFile(from:to:)` | Converts a direct URL string into a `URL` after replacing spaces with `%20`, then downloads it with `URLSession.shared.download(from:)`. | Constructed from caller-provided `urlString`; only space encoding is local. | No app update for URL content changes if valid URL strings are served. App update required for different encoding/validation rules. | Yes, older versions keep the same permissive URL handling. | Avoid spaces in future remote URLs even though current code handles them. Use already percent-encoded HTTPS URLs in `index.json`. |
| Local downloaded team filename: `\(down).ScoreKeep_Players` | `ScoreKeep/ScoreKeep/Sharing Data/ShareContentView.swift` | 303-308 | `ShareContentView.body` `.onChange(of: down)` | Saves a downloaded team roster to the app Documents directory with the selected team name and custom extension. | Constructed local filename. | Yes, changing the extension/import contract requires app update and Info.plist changes. | Yes, old versions continue producing/importing `.ScoreKeep_Players`. | Keep `.ScoreKeep_Players` supported indefinitely. If adding a new format, support both old and new extensions during migration. |
| `https://komakode.com/Teams/message.json` | `ScoreKeep/ScoreKeep/Sharing Data/AnnouncementCenter.swift` | 33 | `AnnouncementCenter` | Remote announcement/message feed endpoint. | Hard-coded full URL literal. | Yes, changing endpoint in app code requires update. Message content changes do not. | Yes. Released builds continue fetching this exact endpoint. | Keep serving this endpoint. Use additive JSON changes and retain the `messages` array contract. Redirect only if all supported clients handle redirects acceptably. |
| `ctaURL` field from `message.json` | `ScoreKeep/ScoreKeep/Sharing Data/AnnouncementCenter.swift` | 11-15 | `RemoteMessage` | Optional call-to-action URL supplied by the remote message feed. | Constructed remotely by JSON content. | No app update to change CTA target if `message.json` schema stays compatible. | Older versions that support announcements will open whatever valid URL is provided by this field. | Use fully qualified HTTPS URLs for CTAs. Keep CTA optional and validate server-side before publishing. |
| `URL(string: cta)` | `ScoreKeep/ScoreKeep/Sharing Data/AnnouncementSheet.swift` | 34-36 | `AnnouncementSheet.content(for:)` | Converts remote CTA string to a URL and opens it. | Constructed from remote `message.json`. | No app update for target changes. | Yes, old clients use the CTA values served by their `message.json` endpoint. | Avoid malformed or unsupported schemes in `ctaURL`; prefer HTTPS. |
| `https://komakode.com/Privacy%20Policy` | `ScoreKeep/ScoreKeep/Common/PaywallView.swift` | 68 | `PaywallView` | Privacy Policy link in the paywall legal links. | Hard-coded full URL literal. | Yes, to change the URL in installed app code. | Yes. Released builds continue opening this exact URL. | Keep this URL available permanently. If canonical URL changes, add a server redirect from `/Privacy%20Policy`. |
| `Manual.pdf` bundle resource | `ScoreKeep/ScoreKeep/Reporting/PdfView.swift` | 23 | `PdfView` | Loads the local user manual PDF from the app bundle. | Hard-coded bundled resource name and extension. | Yes. Any manual content or filename change shipped in the app bundle requires an app update. | Yes. Older released versions keep their bundled manual. | Keep the resource name `Manual.pdf` if replacing the manual in future builds. If a remote manual is ever added, keep local fallback. |
| `Manual.pdf` bundle resource for sharing | `ScoreKeep/ScoreKeep/Reporting/PdfView.swift` | 35-36 | `PdfView.body` toolbar | Shares the bundled manual PDF. | Hard-coded bundled resource name and extension. | Yes. Same as above. | Yes. Older versions share their bundled manual. | Same as above: preserve `Manual.pdf` resource name for compatibility within the app target. |
| `mailto:comment@KomaKode.com?subject=Additional%20download%20request&body=Please%20make%20\(newTeam)%20available%20for%20download` | `ScoreKeep/ScoreKeep/Sharing Data/ShareContentView.swift` | 655-657 | `ShareContentView.sendEmail(openUrl:)` | Opens email composer for requesting an additional downloadable team. | Constructed from hard-coded `mailto:` base plus interpolated team name. | Yes, changing recipient/subject/body template requires app update. | Yes. Older versions continue using this email address and template. | Keep `comment@KomaKode.com` receiving mail or add forwarding. Consider URL-encoding `newTeam` in future code to avoid malformed bodies. |
| `Teams/` | `ScoreKeep/ScoreKeep/Sharing Data/DownloadFiles.swift` | 37-39 | `DownloadFiles.fetchFileList(from:)` | Legacy parser splits fetched text by `Teams/` to derive filenames. No active caller found in current source. | Hard-coded path fragment. | Only if this legacy function is still reachable in older app versions or resurrected. | Potentially yes, older versions may depend on directory listing or text containing `Teams/`. | Keep `/Teams/` paths and redirects available while supporting old releases. Do not remove old file locations without checking App Store build history. |
| `scorekeep://share?tab=download&prefill=...` contract (`scheme=scorekeep`, host `share`, query `tab=download`, optional `prefill`) | `ScoreKeep/ScoreKeep/List Data/StartView.swift` | 187-196 | `StartView.parseDeepLink(_:)` | Routes iPad/deep-link entry into Share/Download Teams flow. | Constructed deep-link contract; not a full literal URL in source. | Yes, changing scheme, host, or query contract requires app update and breaks existing links. | Yes. Older versions keep recognizing only this contract. | Keep `scorekeep://share?tab=download` stable. Add new query parameters only as optional. |
| Same `scorekeep://share?tab=download&prefill=...` contract | `ScoreKeep/ScoreKeep/List Data/StartPhoneView.swift` | 132-140 | `StartPhoneView.parseDeepLink(_:)` | Routes iPhone deep links into the Share tab. | Constructed deep-link contract. | Yes. | Yes. | Keep behavior aligned with `StartView` and `ScoreKeepApp` parsers. |
| Same `scorekeep://share?tab=download&prefill=...` contract | `ScoreKeep/ScoreKeep/Sharing Data/ShareContentView.swift` | 700-708 | `ShareContentView.parseDeepLink(_:)` | Local parser for Share view deep-link destination. | Constructed deep-link contract. | Yes. | Yes. | Avoid changing without supporting the old route. |
| Same `scorekeep://share?tab=download&prefill=...` contract | `ScoreKeep/ScoreKeep/ScoreKeepApp.swift` | 100-109 | `parseDeepLink(_:)` | App-level deep-link parser for Share/Download Teams destination. | Constructed deep-link contract. | Yes. | Yes. | Consider centralizing parser in future production change, while retaining the current route. |
| `scorekeep` URL scheme declaration | `ScoreKeep/ScoreKeep/Info.plist` | 36-46 | `CFBundleURLTypes` | Registers the app to handle `scorekeep:` URLs. | Hard-coded scheme in Info.plist. | Yes, changing registered schemes requires app update. | Yes. Old builds keep only the declared scheme. | Keep `scorekeep` registered. If adding universal links or a new scheme, keep this one too. |
| `.ScoreKeep_Players` import recognition | `ScoreKeep/ScoreKeep/List Data/StartView.swift` | 176-184 | `StartView.isImportFileURL(_:)` | Recognizes shared/imported player files on iPad by extension or filename content. | Hard-coded filename extension strings. | Yes for changing accepted file extensions. | Yes. Older builds only recognize these names. | Continue producing and accepting `.ScoreKeep_Players`. Add new extensions as additional accepted types. |
| `.ScoreKeep_Games` import recognition | `ScoreKeep/ScoreKeep/List Data/StartView.swift` | 176-184 | `StartView.isImportFileURL(_:)` | Recognizes shared/imported game files on iPad by extension or filename content. | Hard-coded filename extension strings. | Yes. | Yes. | Continue producing and accepting `.ScoreKeep_Games`. |
| `.ScoreKeep_Players` / `.ScoreKeep_Games` import recognition | `ScoreKeep/ScoreKeep/List Data/StartPhoneView.swift` | 127-129 | `StartPhoneView.isImportFileURL(_:)` | Recognizes shared/imported files on iPhone by exact extension. | Hard-coded filename extension strings. | Yes. | Yes. | Keep extensions stable; if expanding support, update both iPhone and iPad paths. |
| `.ScoreKeep_Players` / `.ScoreKeep_Games` local validation | `ScoreKeep/ScoreKeep/Sharing Data/ShareContentView.swift` | 691-696 | `ShareContentView.isValidImportURL(_:)` | Validates downloaded/shared files before presenting import UI. | Hard-coded extension strings. | Yes. | Yes. | Keep extension support stable. |
| `\(fileName).ScoreKeep_Players` | `ScoreKeep/ScoreKeep/Sharing Data/ShareContentView.swift` | 486-491 | `ShareContentView.savePlayers(playerData:fileName:)` | Saves user-shared team/player exports. | Constructed local filename with hard-coded extension. | Yes for extension changes. | Yes. | Keep old extension accepted by all import paths. |
| `\(fileName).ScoreKeep_Games` | `ScoreKeep/ScoreKeep/Sharing Data/ShareContentView.swift` | 538-543 | `ShareContentView.saveGame(gameData:fileName:)` | Saves user-shared game exports. | Constructed local filename with hard-coded extension. | Yes. | Yes. | Keep old extension accepted by all import paths. |
| `seededGame.ScoreKeep_Games` | `ScoreKeep/ScoreKeep/ScoreKeepApp.swift` | 82-95 | `SeederView` | Loads bundled seeded game file on first launch. | Hard-coded bundled resource name and extension. | Yes, changing resource name/extension requires app update. | Older builds keep bundled seed file behavior. | Keep seed resource naming stable unless all target references are updated in the same release. |
| `com.komakode.scorekeep` | `ScoreKeep/ScoreKeep/Info.plist` | 16, 19, 42, 66 | `Info.plist` document type / URL name / UTI declaration | App document type and exported UTI for player files. | Hard-coded identifiers. | Yes. | Yes. | Do not rename existing UTIs; add new ones if needed. |
| `com.komakode.scorekeep.games` | `ScoreKeep/ScoreKeep/Info.plist` | 30, 33, 87 | `Info.plist` document type / UTI declaration | App document type and exported UTI for game files. | Hard-coded identifiers. | Yes. | Yes. | Do not rename existing UTIs; add new ones if needed. |
| `com.komakode.scorekeep.ScoreKeep_Players` | `ScoreKeep/ScoreKeep/Common/Extensions.swift` | 56-58 | `UTType.myCustomFile` | Defines a custom UTType for player file transfer. | Hard-coded exported UTI string. | Yes. | Yes. | Keep compatible with Info.plist/document type declarations. |
| `com.komakode.ScoreKeep.SeasonPass` | `ScoreKeep/ScoreKeep/Objects/PurchaseManager.swift` | 21-24 | `PurchaseManager` | Product ID prefix; current year is appended at runtime. Not a URL but a remote StoreKit identifier. | Constructed from hard-coded prefix plus current year. | Yes, changing prefix requires app update and App Store Connect alignment. | Yes. Older versions keep requesting IDs with this prefix. | Keep prefix stable and create future yearly products in App Store Connect before each season. |
| `https://apps.apple.com/account/subscriptions` | `ScoreKeep/ScoreKeep/Objects/PurchaseManager.swift` | 171-172 | `PurchaseManager.openSubscriptionsURLFallback()` | Opens Apple account subscriptions page as a StoreKit fallback. Not KomoKode-hosted. | Hard-coded full URL literal. | Yes. | Yes. | Leave as Apple-owned fallback unless StoreKit flow changes. |
| `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/` | `ScoreKeep/ScoreKeep/Common/PaywallView.swift` | 69 | `PaywallView` | Standard Apple EULA link in paywall. Not KomoKode-hosted. | Hard-coded full URL literal. | Yes. | Yes. | Keep current unless Apple changes required legal URL. |

## Specifically Verified Items

- `Teams/index.json`: present as hard-coded `https://komakode.com/Teams/index.json` in `ShareContentView.getFileNames()` and as a model comment in `DownloadFiles`.
- `Teams/message.json`: present as hard-coded `https://komakode.com/Teams/message.json` in `AnnouncementCenter`.
- Team file download URLs: not hard-coded locally in current active flow; supplied by `index.json` `teams[].url` values, then downloaded by `DownloadFiles.downloadFile(from:to:)`.
- `Manual.pdf`: present as bundled local resource in `PdfView`; no remote fetch.
- Privacy policy: present as `https://komakode.com/Privacy%20Policy` in `PaywallView`.
- `komakode.com` home page: no standalone home-page link found.
- `media.komakode.com`: no references found.
- Legacy URLs/paths: `DownloadFiles.fetchFileList(from:)` still contains legacy `Teams/` text-splitting logic; no active caller found in current source.

## Compatibility Recommendations

1. Keep `https://komakode.com/Teams/index.json`, `https://komakode.com/Teams/message.json`, and `https://komakode.com/Privacy%20Policy` available for the lifetime of supported released builds.
2. Use `index.json` as the stable compatibility layer for team downloads. Move team files by changing `teams[].url`, while keeping old file URLs redirected or served.
3. Preserve the existing JSON fields used by the app: `updated`, `divisions`, `divisions[].name`, `divisions[].teams`, `teams[].name`, `teams[].url`, `messages`, `ctaTitle`, `ctaURL`, `title`, `body`, `start`, and `end`.
4. Keep `.ScoreKeep_Players`, `.ScoreKeep_Games`, `scorekeep://share?tab=download`, and existing `com.komakode...` identifiers stable. Add new formats/routes alongside them rather than replacing them.
5. If hosting moves to `media.komakode.com`, do it through server-side indirection: keep old KomoKode endpoints live and put new media URLs inside `index.json` only after verifying older clients handle the target URLs.
6. Configure Cloudflare rules so human-facing fallback routing does not intercept ScoreKeep compatibility resources. Test the exact URLs for status, content type, and body content after every website deployment.
