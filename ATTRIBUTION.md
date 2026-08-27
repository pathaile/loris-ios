# Attribution

## AdNauseam (reference)

This project’s privacy-lab design is **conceptually informed** by AdNauseam:

- Repository: https://github.com/dhowe/AdNauseam  
- License: GPLv3  
- Authors: Daniel C. Howe and contributors  

Relevant conceptual mappings (not a line-for-line port):

| AdNauseam idea | Loris research equivalent |
| --- | --- |
| Ad detection via filter/DOM signals | Traffic probe + matcher + content rules |
| Ad Vault / admap history | Local `AdVaultStore` |
| Visitation / interest dilution | Background decoy loads of public category pages |
| Click simulation on ad targets | **Not ported** — paid-click URLs are skipped and logged |

No AdNauseam source files were copied into this tree. If future work incorporates AdNauseam code directly, that code (and the combined work as required) must be distributed under GPLv3.
