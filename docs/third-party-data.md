# Optional tag dictionary

NextN does not bundle tag-translation data. A user may explicitly choose **Download** or **Update** in Settings to retrieve the current compressed dictionary from the public [EhTagTranslation/Database](https://github.com/EhTagTranslation/Database) release asset. If the direct HTTPS download fails, the same fixed asset is retried through the configured HTTPS mirror; no cookies or credentials are sent to either source.

- The request is a public HTTPS `GET`; NextN sends no account credential, cookie, token, or upload.
- The file is held only in app-private temporary storage during validation and import. A successful parse replaces the encrypted local RDB dictionary in one transaction; a failed update keeps the previous dictionary.
- The dictionary changes Gallery tag labels and can provide bounded on-device `namespace:prefix` suggestions. Search always receives the original raw tag syntax; a translated display name is never sent as a query.
- The provider publishes its data under [CC BY-NC-SA 3.0 China Mainland](https://github.com/EhTagTranslation/Database/blob/master/LICENSE.md). The optional data must not be used for commercial distribution, and any distribution/attribution obligations must be reviewed before release.
