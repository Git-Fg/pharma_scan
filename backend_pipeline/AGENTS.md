Make sure to always maintain optimal type safety. 

Priorize simplicty and efficiency over over-engineering : less is more. 

After performing change in the logic, make sure to always keep synchronised the README and idea.md and test suite. 


The goal of this backend is to produce the db easily usable, make sure the tools never introduce custom logic for clustering/parsing that'd not be "exported" in the db. 


Never separate cluster between administration route, e.g. amoxicille should belong in the clamoxyl cluster no matter its formulation. 


Make sure to always run "bun run build:bd" ; "bun run test" and "bun run tool" at the end of the process of each answer. 

Never hesitate to leverage sqlite3 cli command to inspect the db. 