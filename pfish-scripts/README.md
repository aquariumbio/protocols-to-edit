Get the installation script:

`wget -vO- https://raw.githubusercontent.com/aquariumbio/protocols-to-edit/main/pfish-scripts/pfish-install.sh`

This will download the pfish wrapper script and install it in `~/bin`. You will probably need to add this to your PATH. 

type `pfish update`
type `pfish version` — it should tell you that you have the testing version.

Add a configuration for your local aquarium: `pfish configure add -l <your-login> -p <your-passworld> -u <url>`

The url is wherever you are connecting to [localhost](http://localhost) — 
For most of you this is just `https://localhost` but for some of you it's  `http://localhost:3000` 

Type `pfish configure show` — it should show you what you just typed.

Provided you are currently connected to Aquarium locally, you should be able to push and pull and protocols. 

The instructions in the pfish repo cover most of the possibilities. 
But, since this is a test version that I made to skip over some of the buggy stuff that you won't need, I would recommend only pushing a single operation type at time. Which, since you'll only be working on one at a time, should be easiest anyway. 

The Command for pushing is
`pfish push -d <your-directory-name> -c <your-category-name> -o <your-op-type-name>`
    
e.g. if you are working on "combine and dry dna" and are in the "protocols to edit repo", you would do:

`pfish push -d ./ -c "library cloning" -o "combine and dry dna"`

Or, if you are one level up from the "protocols-to-edit" folder you would do:

`pfish push -d protocols-to-edit -c "library cloning" -o "combine and dry dna"`


