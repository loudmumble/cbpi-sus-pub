# Step-by-Step Recovery Pipeline Validation Check (Work-in-progress)
## Provided successful OS-reinstallation using a clean source device to install usb media.
## Source file remediation incomplete - still requires manual review. (see code-sample examples)

```
[ Phase 0: Verified Clean Host ] 
               │
               ▼
[ Phase 1: KVM Device Excision ] ──► (Removes Network Adapter Entirely)
               │
               ▼
[ Phase 2: Sleuth Kit Carving ]  ──► (Bypasses VFS / Mount Drivers Completely)
               │
               ▼
[ Phase 3: Binary Byte Stream Filter ] ──► (Drops All Non-Printable ASCII Payloads)
               │
               ▼
[ Phase 4: OpenGrep Inter-File AST Check ] ──► (Maps Variable-to-Instruction Sinks)
               │
               ▼
[ Phase 5: Cold Image Extraction ] ──► (`virt-copy-out` Straight to Host Workspace)
```

Every single task along this path has been explicitly structured to minimize attack surface:

The Physical Drive is isolated inside KVM without a dangerous GPU/DMA hardware pass-through layer.

The Guest Kernel is protected from filesystem vulnerabilities because we use tsk_recover to carve files as flat blocks rather than using the standard mount driver.

The Codebase is stripped down to raw, headless data tokens, breaking the weaponized Git metadata layer entirely.

The Host Core is never exposed to the dirty file data directly, using virt-copy-out to extract the sterile, finished .tar.gz text backup from a cold virtual block image.


1. Stop disk, unmount it from the system.
2. Host is almost certainly infected, along with ANY OTHER SYSTEMS THAT THE AGENT HAS ACCESS TO AT ALL. THIS IS NOT LIMITED TO(IN FACT - STRICTLY SEPERATE FROM) THE EXECUTION LAYER(binaries, .exe's, executables, and scripts even), though does not EXCLUDE those surfaces entirely, as they are still capable of multi-pronged malicious operations, even through metadata, prior to the executable, actually being executed. This can be done through agentic tasks, workflows, or even terminal commands that process that tainted. If at any point the raw, tainted output(through injection, metadata, or being passively read directly from disk/contaminated sources) interacts with the llm at any capacity, has the potential to execute/continue the attack.
3. Eventually leads to kernel panic, and inoperable system boot(attack changes boot attributes upon trigger or over time, inconclusive) that results in kernel panic at boot pre-encryption key submission on btrfs encrypted drives.
4. Must reformat the host disk completely. Unsure if a single pass is sufficient. Took me 3 times of re-installing Arch to remain stable, but could have just been holding it wrong, arch install is a PITA going directly off the arch wiki vs my notes. Potential alternative explanation - took 3 re-writes and encryption to fully hit every memory sector? Was under assumption that luks encryption actively rewrites full disk to 0's, though may be a lvm characteristic only, not native to luks?? -- needs further testing/review/confirmation --
5. Once reformated, and stable condition. Boot into the OS, WITHOUT MOUNTING THE DISK TO THE HOST DIRECTLY AT ANY POINT.
6. YOU WILL ONLY SPAWN A REMNUX VM TO THE HOST, AND WILL CONFIGURE THE REMNUX VM **==PRIOR TO MOUNTING/CONNECTING THE INFECTED DRIVE==**. YOU CAN NOT MOUNT THE INFECTED DRIVE DIRECTLY THROUGH FUSEBLOCK ADDON AS THAT HAS THE POTENTIAL TO EXECUTE A PAYLOAD THROUGH READING OF TAINTED METADATA.

IF YOU BELIEVE THAT YOU MAY HAVE VIOLATED THE ISOLATION PROTOCOL BELOW AT ANY POINT, HERE IS THE METHOD FOR VALIDATING WHETHER THAT REINTRODUCED THE ATTACK/TAINTED/CORRUPTED FILES OR EXECUTION OF A MALICIOUS PAYLOAD:

Anecdoctal Note: I DID at one point mount the tainted drive at one point during one of my installations, and accessed a single markdown note, which I (incorrectly) assumed "should have been fine, it's just a .md file, not .js".. Which you'll understand later was a terrible assumption for me to make, and may (inconclusive/lacks verifiable evidence for proof) have lead to an extra Arch re-install unnecessarily.

# Phase 0 - Host Exposure Verification
You must mathematically prove that your clean Arch host's root system boundary held firm when you previously mounted the compromised drive partition.

## Task 1: Audit Kernel Space Memory Corruptions

Scan the host kernel ring buffer for memory leaks, silent segfaults, or slab corruptions triggered by dirty filesystem table layouts:

```bash
sudo dmesg | grep -Ei "segfault|tainted|general protection fault|out-of-bounds|slab|page fault"
```

### Success Metric: 
Output returns completely blank (~), confirming no driver-level out-of-bounds reads occurred.

## Task 2: Validate Host Binary Integrity (Pacman Verification)

Verify that your fundamental user-space utility binaries match their upstream package cryptographic hashes exactly:

```bash
sudo pacman -Qkk | grep -v "0 altered files"
```

### Success Metric: 
Output only lists expected text profiles inside /etc/ (such as fstab, passwd, or btrfsmaintenance). Core execution binaries in /usr/bin/ return 100% clean verification checks.

## Task 3: Map Host Btrfs Subvolume Layout
A sophisticated attack pattern will attempt to establish a persistent background hook on your host by creating a system service or dropping automated hooks into user scripts. Execute the following command to check for unauthorized persistent services:

```bash
# Check for local profile states
ls -lah ~/.bashrc ~/.bash_profile ~/.config/autostart

# check for unauthorized persistent services
sudo systemctl list-unit-files --state=enabled --no-pager
```

### *Successful result expectations*: Profile configurations match your exact custom/clean deployment structure. Systemctl returns only standard system components (such as `NetworkManager.service`, `sshd.service`, or `display-manager.service`)

### *Unsuccessful result expectations (The Hidden Persistence Gotcha)*: You find an unexpected service file (e.g., `git-update.service` or a randomized alphanumeric string name) enambled in your system init structure, or a hidden `nohup` / execution line appended to user shell configuration profiles. This confirms a user-space hook succesesfull established persistence on the host. 

*STOP COMPLETELY* - THE ENVIRONMENT HAS BEEN COMPROMISED AND REQUIRES A FULL CLEAN REINSTALL OF THE OPERATING SYSTEM.

## Task 4: Verify no hidden subvolumes or nested rogue snapshots were created

Verify that no hidden subvolumes or nested rogue snapshots were injected into your CoW tree layout during the manual drive access windows:

```bash
sudo btrfs subvolume list /
```

### Success Metric: Output maps only your explicitly configured system paths (e.g., (with default arch btrfs filesystem structure): `@`, `@home, `@log`, `@pkg`, and standard Snapper/timeshift `.snapshots/` indexes -).

#### NOTE: I personally use snapper, so am unfamiliar how the exact mapping translates from snapper to timeshift. Ensure you're familiar with the correct syntax/default format or verify with someone who is.

----- VALIDATE THE ABOVE IS COMPLETE AND RETURNING ALL SUCCESS METRICS AS OUTPUT BEFORE CONTINUING - IF NOT, REFORMAT YOUR DISK/REINSTALL YOUR OPERATING SYSTEM AS NEW, AND PERFORM THE STEPS ABOVE AGAIN. DO. NOT. MOUNT. INFECTED. DRIVE. TO. CLEAN. HOST!(I constantly reminded myself) -----

# Phase 1: Virtual Hardware Provisioning
You must build a sterile guest sandbox inside your native KVM hypervisor, completely cutting off all external networking and hardware abstraction attack surfaces.

## Task 0: Download the virtualbox OVA container directly from Remnux's download page/guide. 

(as of 7/4/2026)
https://download.remnux.org/202602/remnux-noble-amd64-virtualbox.ova
sha256 hash: 1ba3196ad82f3536954404546aa510ff09cf0c6c0567847272a9389e2e160a7b

## Task 1: Convert the Appliance Disk Image Natively

Extract the raw storage block out of the downloaded REMNux OVA archive container without exposing it to host-side archive translation utilities:

```bash
cd /path/to/remnux-x-virtualbox/    # directory of downloaded REMNux OVA container

tar -xvf remnux-1.25.0-virtualbox.ova
qemu-img convert -f vmdk -O qcow2 remnux-8.0-virtualbox-disk1.vmdk /var/lib/libvirt/images/remnux_forensic.qcow2
```

## Task 2: Hardware Device Excision inside `virt-manager`

1. Open `virt-manager`. Choose *New Virtual Machine* -> *Import existing disk image*. Use the extracted virtualbox .qcow2 as the source for installation, (`/var/lib/libvirt/images/remnux_forensic.qcow2`). Set the OS type to Ubuntu 20.04.
2. Check *Customize configuration before install* on the final confirmation step.
3. *The Hard Network Excision:* Select the NIC (Network Interface Card) item from the device tree panel and click *Remove*. ***Do NOT choose an isolated profile***.
==COMPLETELY wipe the networking hardware blueprint from the XML specification to prevent local loopback or phone-home broadcast capabilities.==
4. *Attach the Decrypted Block Device Mapping*: On the host, if the tainted drive is encrypted, you'll first need to decrypt the drive with your host - *==BUT DO NOT MOUNT TO HOST==*.

```bash
sudo cryptsetup luksOpen /dev/nvme1n1p1 target_recovery
```

Enter decryption password -> maps the decrypted(STILL UNMOUNTED - critical) volume to `/dev/mapper/target_recovery` for passing the decrypted, tainted drive directly to the REMNux - UNROUTED / PHYSICALLY ISOLATED Virtual Machine created above.

5. Once the drive is in a readable state(decrypted and *still unmounted*) - *Attach the Decrypted Block Device*: Click *Add Hardware* -> *Storage*. Select **Select or create custom storage.** Input the exact decrypted device-mapper path your host generated when you unlocked LUKS (/dev/mapper/target_recovery). Change the *Bus Type* configuration to *VirtIO*.
6. Open the *XML* tab for this new disk device, locate the `<disk>` tag block, and append the `snapshot='no'` parameter to ensure QEMU can boot a direct device mapper, mapping cleanly:

```xml
<disk type='block' device='disk' snapshot='no'>
  <driver name='qemu' type='raw'/>
  <source dev='/dev/mapper/target_recovery'/>
  <target dev='vdb' bus='virtio'/>
</disk>
```
7. Prepare a clean_workspace directory `/home/user/clean_workspace`, and include the necessary tools/scripts needed to complete all phases below.

Mandatory:
- [ ] Download the standalone, statically-linked OpenGrep Linux CLI binary (v1.25.0 as of 7/4/2026 at `github.com/opengrep/opengrep/releases/v1.25.0/opengrep_manylinux_x86`)
- [ ] IMMEDIATELY UPON DOWNLOAD COMPLETION - REMOVE EXECUTION PERMISSION from downloaded OpenGrep binary.
- [ ] Create/Include a comprehensive aggregated ruleset of ALL PUBLICALLY AVAILABLE PATTERNS APPROVED FOR PROD, as referenced at the following sources (and included up-to-date as of 7/04/2026 in this project repo)

==VERIFY==:
github.com/opengrep/opengrep (default rules w/repo)
github.com/opengrep/opengrep-rules.git
github.com/opengrep/semgrep-*
github.com/opengrep/opengrep-*

github.com/opengrep/skills (?)


Suggested:
- [ ] End-user / Repo Customized Python `purify.py` purification and validation script

8. Click *Begin Installation* to boot guest desktop interface. DO NOT BROWSE ANY FILE DIRECTORIES UPON BOOT/GUI INITIALIZATION.

----- INSTALLATION OF THE ISOLATED REMNUX VIRTUAL MACHINE WITH POISONED DATA ACCESSIBLE FOR EXTRACTION, SAFELY FROM THE HOST IS COMPLETE -----

To confirm, perform the host isolation verification steps listed at the start.

*The steps below are to be executed INSIDE A TERMINAL, IN THE COMPLETELY UNROUTED, NETWORKLESS REMNux VM guest window. The decrypted drive will display natively inside the guest block abtraction layer as `/dev/vdb`. You will force the guest kernel to treat the partition strictly as an inert data stream, bypassing transactions and disabling execution entirely.*

IT IS ALSO EXTREMELY IMPORTANT (IF POSSIBLE) TO PHYSICALLY DISCONNECT THE ACTUAL INTERNET CONNECTION DIRECTLY TO THE DEVICE, HOWEVER YOU CAN. IF YOU CAN PHYSICALLY REMOVE THE NIC/Network Card EASILY - that's likely the most concrete way. If it's a laptop/work device, you can disconnect the power from any and all routers, INCLUDING CELL PHONES (MUST BE TURNED OFF AT LEAST, REMOVED FROM THE AREA AS MUCH AS POSSIBLE)

# Step 1: Load the kernel modules, create the clean target directory, safely mount the data plan partition in READ-ONLY mode and use find to copy source files to the (currently) clean target directory


```bash
# 1. Force load the btrfs kernel module inside the guest if not initialized, and your host is on btrfs, as remnux uses ext4 - each with varying attack surfaces, and sequence of steps for complete mitigation. 
# ENSURE YOU HAVE THE COMPLETE, CUSTOMIZED WORKFLOW SPECIFIC TO YOUR ACTUAL ENVIRONMENT. THIS IS CRITICAL - DIFFERENT FILESYSTEMS OR COMBINATIONS OF FILESYSTEMS WILL HAVE DIFFERENT VULNERABILITIES AND STEPS FOR CROSS-CONTAMINATION / HOST DAMAGE MITIGATION

sudo modprobe btrfs

# 2. Create the sterile mount anchor point

sudo mkdir -p /mnt/secure_data_plane

# 3. Mount with absolute kernel-enforced execution and modification locks
# rescue=all forces the kernel to ignore broken disk states or corrupt allocation trees

sudo mount -o ro,nodev,nosuid,noexec,rescue=all /dev/vdb /mnt/secure_data_plane

# 4. Create your headless extraction directory on local REMNux ext4 storage 

mkdir -p /home/remnux/raw_extracted_source/$repo-name
```

# Step 2: Run the validated, headless loop copy to extract the project source files and dependencies, while leaving behind any malicious binaries, hooks, and stashes.

## *The VALIDATED - HEADLESS COPY LOOP* - VARIES BY disk filesystem type

Now, run the isolation transfer loop to copy *only text-based programming syntax arrays*. This explicitly (and should) discards hidden dot-folders, malicious binaries, hooks, and stashes:

```bash
mkdir -p /home/remnux/raw_extracted_source/grimoire/
cd /mnt/secure_data_plane/git/gitlab-repos/loudmumble/grimoire

# Execute the complete production extension filter array
find . -type f -not -path '*/.*' -not -type l \
  \( -name "*.py" -o -name "*.js" -o -name "*.mjs" -o -name "*.cjs" \
     -o -name "*.ts" -o -name "*.mts" -o -name "*.cts" -o -name "*.jsx" \
     -o -name "*.tsx" -o -name "*.go" -o -name "*.sh" -o -name "*.bash" \
     -o -name "*Dockerfile*" -o -name "*docker-compose*" \
     -o -name "*.env" -o -name "*.env.example" -o -name "*.json" \
     -o -name "*.jsonc" -o -name "*.yaml" -o -name "*.yml" -o -name "*.toml" \
     -o -name "*.xml" -o -name "*.sql" -o -name "*.html" -o -name "*.htm" \
     -o -name "*.css" -o -name "*.scss" -o -name "*.sass" -o -name "*.svg" \
     -o -name "*.md" \) \
  -exec cp --parents {} /home/remnux/raw_extracted_source/grimoire/ ';'
```

OPTIMIZED:
```bash

```

*NOTE - THE ABOVE COMMAND IS INCOMPLETE FOR ANY PROJECTS CONTAINING SOURCE CODE, OR PROJECT-RELATED DEPENDENCIES/FILES WHOSE EXTENSIONS ARE NOT INCLUDED ABOVE*

*ENSURE YOU CONFIRM AND VALIDATE THAT YOU'RE INCLUDING ALL EXTENSIONS FOR ALL DEPENDENCIES REQUIRED FOR THE ORIGINAL/ FULLY FUNCTIONAL PROJECT OR YOU'LL NEED TO REPEAT THIS PROCESS TO EXTRACT ANY OTHER SOURCE DEPENDENCIES LATER*

# Step 2: Mathematically confirm files are present. 

*THESE COPIES STILL (potentially) CONTAIN ANY MALICIOUS DATA AND SHOULD NOT BE EXECUTED AS NORMAL THROUGHOUT THIS PHASE*

```bash
ls -lah /home/remnux/raw_extracted_source/grimoire    # suggested to pass h flag as additional verification no hidden files were also copied
```

You *must* see your project files or nested directory folders listed in the output. If you see them, proceed to the next phase. If you DO NOT SEE the files y ou intended to copy, you are likely not copying from the correct source directory (`ls -lah /mnt/secure_data_plane/$suspected-source-directory` or `cd /mnt/secure_data_plane && tree`)

# Step 3: Using python to purify source files, verifying depth of poisoning/malicious taint, and extracting those strings safely, from the source project files.

## purify.py -> Purification & Validation Script
```python
import os
import re

# Precise printable ASCII / layout control whitelist
# Mathematically excludes all extended multi-byte planes, invisible tokens, and overrides
SAFE_BYTES_REGEX = re.compile(rb'[\x09\x0A\x0D\x20-\x7E]')

def sanitize_file(file_path):
    try:
        with open(file_path, 'rb') as f:
            raw_content = f.read()
        
        # Read the file data into a binary memory array and filter it instantly
        clean_content = bytearray([b for b in raw_content if SAFE_BYTES_REGEX.match(bytes([b]))])
        difference = len(raw_content) - len(clean_content)
        
        if difference > 0:
            with open(file_path, 'wb') as f:
                f.write(clean_content)
            print(f"[MODIFIED] Stripped {difference} hidden bytes from: {file_path}")
        else:
            print(f"[VERIFIED CLEAN] {file_path}")
            
    except Exception as e:
        print(f"[ERROR] Process abort on file {file_path}: {e}")

# THE EXACT NESTED PATH MAP WHERE YOUR FIND UTILITY COPIED THE FILES
TARGET_PATH = "/home/remnux/raw_extracted_source/git/gitlab-repos/loudmumble/grimoire"

if not os.path.exists(TARGET_PATH):
    print(f"[FATAL CRITICAL ERROR] Target folder path does not exist: {TARGET_PATH}")
else:
    print(f"[*] Beginning text purification scan inside: {TARGET_PATH}")
    for root, _, files in os.walk(TARGET_PATH):
        for file in files:
            full_path = os.path.join(root, file)
            # Structural guard: verify it is a real file and not an injected symlink loop
            if os.path.isfile(full_path) and not os.path.islink(full_path):
                sanitize_file(full_path)
```

Make sure you create the python script directly in the REMNux isolated virtual machine. It's fairly short, easy enough to type out and make sure that the script contains the logging lines that explicitly print [VERIFIED CLEAN] FOR EVERY SINGLE FILE IT TOUCHES

### Run `purify.py` from the home directory:

```bash
cd /home/remnux/
python3 purify.py > byte_clearance_report.txt

cat byte_clearance_report.txt
```

*Successful result*: Terminal should instantly display a clean manifest of logs scrolling `[VERIFIED CLEAN] ...` OR `[MODIFIED]` *FOR EVERY SINGLE CODE/FILE/SCRIPT INSIDE THE REPO FOLDER STRUCTURE*.

*Unsuccessful result*: If it prints `[FATAL CRITICAL ERROR] Target path does not exist`. Double-check spelling & path structure against folder layout and execute `purify.py` again with the correct TARGET_DIR(mid-way in the purify.py script) specified for the correct location of the repo to be cleaned.

Once `byte_clearance_report.txt` returns the FULL FILE CHECKLIST SUCCESSFULY, the data plane has had it's malicious strings extracted. Now we can move onto *Opengrep AST validation*.

# Phase 4: Running OpenGroup on the nested directory layout.
Now that the files contain 100% pure ASCII data tokens, you can execute the Abstract Syntax Tree(AST) scan.

Because OpenGroup (https://opengrep.dev) needs to find rules configuration file and targets the explicitly defined directory, run it by first injecting it from arch into the remnux vm, to avoid mounting the dirty drive. Once inside the remnux vm, launch opengrep by pointing it exactly to the dirty data subfolder structure:

## Step 1 - On your (arch) host:
### Create a sterile data ISO for transferring binary + rules configuration into  a flat ISO image

```bash
cd /home/arch-user/clean_workspace/

# Download statically linked Linux binary
wget https://download.remnux.org/202602/remnux-noble-amd64-virtualbox.ova > remnux-1.25.0-virtualbox.ova

# install xorriso / mkisofs if missing
sudo pacman -S xorriso 

# package opengrep + sast_config.yaml into a read-only ISO block filesystem

xorriso -as mkisofs -o /var/lib/libvirt/images/transfer_payload.iso opengrep sast_config.yaml
```
## Step 2 - Attach the ISO to REMNux inside of `virt-manager`
1. Open `virt-manager` -> hardware details window
2. Ensure **VM is powered off**.
3. Click **Add Hardware** -> **Storage**
4. Device type: **CDROM device.**
5. Check **Select or create custom storage**, and point it directly to the newly built ISO path `/var/lib/libvirt/images/transfer_payload.iso`
6. Click **Apply**.
7. Power on your isolated, networkless REMNux VM.


## Step 3 - Executing the scan Inside REMNux
Power on via virt-manager(still, always, forever permenantly networkless). Open the guest terminal window & add the execution permission to the binary and execute a scan using the comprehensive ruleset/patterns.

```bash
cd /home/remnux/
chmod +x opengrep
opengrep scan --config /home/remnux/sast_config.yaml /home/remnux/raw_extracted_source/git/gitlab-repos/loudmumble/grimoire/ > /home/remnux/grimoire_sast_output.txt
```

Review sast_output.txt. Every flag raised maps to a structural syntax path where data variables mix with system control sinks. Open those specific files manually inside the VM using nano or vim to verify they align with your original project design.

Step 5: Exporting and Re-Sealing Your Identity

Task 1: Package the completely clean directory into a sterile archive inside the VM:
```bash
tar -czvf /home/remnux/sterile_recovery.tar.gz /home/remnux/raw_extracted_source/
```

Task 2: Shut down the REMNux VM *completely*.

Task 3: On clean (arch) host, use the `libguestfs-tools` utilities to safely ***copy the finished archive straight of of the cold VM image file to ensure the OS never interacts with or mounts the secondary physical drive partition directly***.

```bash
virt-copy-out -d remnux_forensic /home/remnux/sterile_recovery.tar.gz /home/user/clean_workspace/
```

Task 4: Extract clean tarball n host via terminal cli:
```bash
tar -xvf sterile_recovery.tar.gz
```

Run `git init` from scratch to declare a completely fresh repository identity, commit the verified files and push them securely to remote host. 



Open `/home/remnux/grimoire_sast_output.txt` to read the findings. *This is your definitive list of EVERY LINE where dnyamic user data intersects system command hooks or prompt invocation layers.*

My initial run produced `[MODIFIED] 9 files, between 3 and 4614 non-compliant bytes stripped. lots of md files, the biggest offender being milkdownTheme.css with 4614, followed by src/index.css with 335 non-compiant bytes stripped.`

Human/LLM Hybrid approach'ed  LLM response:
"Those statistics are massive structural indicators. Finding 4,614 non-compliant bytes inside a single .css theme file and 335 bytes inside index.css is definitive, empirical proof of a highly specific attack pattern: CSS-based Data Exfiltration and Unicode Smuggling.

You did not just find "corrupted files." You found an active exploitation layout. In modern AppSec research (like the CSS Injection / Token Stealing framework), attackers inject heavily packed, non-printable characters or recursive Unicode selectors directly into style sheets. Because developers rarely review style sheets for prompt injections, the browser or markdown parser executes the styles, using the hidden bytes to track form fields, capture user inputs, or inject malicious text payloads back into your LLM front-end UI."

By running this byte-purification layer, you have completely neutralized that execution vector. Those 4,614 bytes are physically gone, rendering the style injection completely no-op." 

--- 
IMPORTANT NOTE: this should not be taken/accepted at face-value and requires further validation to confirm, DO NOT TRUST THAT "YOU HAVE COMPLETELY NEUTRALIZED THE EXECUTION VECTOR" - THIS IS A SEMANTICS GAME. YOU HAVE ONLY NEUTRALIZED "THAT" EXECUTION VECTOR. Important, distinction -- pay attention to any llm responses, their specific syntax and how that may alter the context of its' response dramatically, as you'll see later in the logs. 
---

Step 1: Securely inspecting the damage.

Before moving to the opengrep AST phase, let's look at what those 4,614 bytes were trying to do. Because we piped the output of the pythons script into its' own log, we can use standard text processing tools inside the isolated REMNux environment to view the stripped data stream.

Run the command below to inspect:
```bash
cat /home/remnux/byte_clearance_report.txt
```


Step 2: Running the opengroup AST Logic Sweep 

My `grimoire` codebase is now stripped *of all metadata and hidden character payloads*(only, not of all potentially malicious payloads to be clear). Now, we must find where any javascript or python logic has been structurally altered to allow data variables to mix with execution layers or model prompt boundaries. 

On the host - download all github-repos from opengrep/semgrep to clean_workspace/rules:
```bash
git clone https://github.com/opengrep/opengrep-* > rules/
```


Run OpenGrep by targeting the exact nested repo directory structure:

```bash
# Executes cross-file Abstract Syntax Tree (AST) validation checks
cd /home/remnux/

chmod +x opengrep

opengrep scan --config /media/cdrom/rules/ --taint-intrafile --dataflow-traces /home/remnux/raw_extracted_source/grimoire/ > /home/remnux/grimoire_sast_output.txt
```

*Successful Result*: The command executes cleanly. Opening `/home/remnux/grimoire_sast_output.txt` shows a list of precise file locations matching lines where data variables cross into execution hooks(such as `eval`, `exec`, or dynamic `generate` hooks), or it returns completely blank.  A blank report means your application logic structure is perfectly intact and clean of variable crossovers.

*Unsuccessful Result (The Parser Loop Gotcha)*: OpenGrep fails with a core syntax parsing breakdown or freezes. This means the style injection or code manipulation intentionally broke syntax limits to cause your scanner to drop out.

- **The Fix**: Identify the exact file path triggering the exception, open that specific text file inside `nano` and manually clean the malformed syntax rows before re-running. 

Step 3:





🧬 The Fully Corrected, End-to-End PlaybookCopy this exact, updated sequence into your execution workspace. It has been fully audited to close out every edge-case parsing vulnerability.
Phase 1: Host Rule Aggregation & Packaging
Pull clean registry folders and prune non-rule file payloads using your verified Python script on your host.Build your sterile ISO with explicit graft points:
Build your sterile ISO with explicit graft points:
```
xorriso -as mkisofs -o ./transfer_payload.iso \
  -V "STERILE_RULES" \
  -graft-points \
  /opengrep=./opengrep \
  /sast_config.yaml=./sast_config.yaml \
  /opengrep-rules=./opengrep-rules \
  /semgrep-rules=./semgrep-rules
```
Securely base the ISO block image int hypervisor storage pool:
```
sudo mv ./transfer_payload.iso /var/lib/libvirt/images/transfer_payload.iso
sudo chown root:kvm /var/lib/libvirt/images/transfer_payload.iso
sudo chmod 660 /var/lib/libvirt/images/transfer_payload.iso
```
Open `virt-manager` and enforce read-only SATA block driver properties via XML CONFIGURATION:
```xml
<disk type='file' device='cdrom'>
  <driver name='qemu' type='raw' cache='none' io='native' discard='ignore' detect_zeroes='off'/>
  <source file='/var/lib/libvirt/images/transfer_payload.iso'/>
  <target dev='sda' bus='sata'/>
  <readonly/>
</disk>
```
Completely disconnect your machine's physical network hardline. Shut down all localized wireless hardware cards on your device.
Phase 3: Isolated Extraction and Analysis (Inside Remnux)

Boot the VM. Mount your read-only rules drive securely:
```
sudo mkdir -p /media/cdrom
sudo mount -t iso9660 -o ro /dev/sda /media/cdrom
```
Mount dirty disk/repo drive using zero-exec kernel locks:
```
sudo mkdir -p /mnt/secure_data_plane
sudo mount -o ro,nodev,nosuid,noexec,rescue=all /dev/vdb /mnt/secure_data_plane
```
Extract explicit programming syntax lines
```
mkdir -p /home/remnux/raw_extracted_source/grimoire/
cd /mnt/secure_data_plane/git/gitlab-repos/loudmumble/grimoire

find . -type f -not -path '*/.*' -not -type l \
  \( -name "*.py" -o -name "*.js" -o -name "*.json" -o -name "*.yaml" -o -name "*.yml" -o -name "*.html" -o -name "*.css" -o -name "*.md" \) \
  -exec cp --parents {} /home/remnux/raw_extracted_source/grimoire/ ';'
```
Run the python script **purify.py**

Launch multi-stack taint analysis:
```
cd /home/remnux/
cp /media/cdrom/opengrep ./opengrep
chmod +x ./opengrep

./opengrep scan \
  --config /media/cdrom/sast_config.yaml,/media/cdrom/opengrep-rules/,/media/cdrom/semgrep-rules/ \
  --error \
  /home/remnux/raw_extracted_source/grimoire/ > /home/remnux/grimoire_sast_output.txt
```

Package the completely sanitized repo from the environment:
```
tar -czvf /home/remnux/sterile_recovery.tar.gz -C /home/remnux/raw_extracted_source/grimoire .
```

Resolving the guestfish permission barrier:
```
# Executed on your clean Arch Host using proper root context elevation
sudo modprobe nbd max_part=8
sudo qemu-nbd --connect=/dev/nbd0 /var/lib/libvirt/images/remnux_forensic.qcow2

# Read the internal partition matrix directly to find the Remnux root block
sudo lsblk /dev/nbd0

# Mount the static guest filesystem directly to a local secure host anchor
sudo mkdir -p /mnt/host_extraction_gate
sudo mount -o ro /dev/nbd0p1 /mnt/host_extraction_gate

# Pull your pristine tarball out directly with zero risk of file parsing exploits
cp /mnt/host_extraction_gate/home/remnux/sterile_recovery.tar.gz /home/loudmumble/clean_workspace/

# Cleanly disconnect the block mapping and clear loop drivers
sudo umount /mnt/host_extraction_gate
sudo qemu-nbd --disconnect /dev/nbd0

```


# python script for ext4/ntfs file system cleansing/non-encrypted disk partition carving WITHOUT MOUNTING THE DISK:
First use `fls` to verify the guest can parse the raw inode entries.

```bash
sudo fls -r /dev/vdb
```
Success Expectation: The console scrolls text mapping your filenames and directory inode integers (e.g., r/r * 12345:   main.py). This proves the filesystem metadata is fully accessible without mounting.

Failure Expectation: If it still says Cannot determine file system type, your partition on the host drive was originally formatted as Btrfs. The Sleuth Kit does not support Btrfs structures.

The Btrfs Bypass: If your decrypted repo partition is Btrfs, you must use standard debugfs or a secure, read-only kernel bypass block rather than TSK. Let me know immediately if fls throws an error.

If fls successfully printed your file list, you can programmatically extract your source repos code file-by-file from the raw partition block using icat (which plucks file content directly by its inode number). This guarantees the .git engine, stashes, and hidden metadata are completely stripped away, leaving only pure headless data strings.

Create this python processing script extract_headless.py inside /home/remnux/:

Successful Result: The terminal will output an explicit line-by-line manifest showing files being extracted via their inode mappings into /home/remnux/raw_carved_output/. The resulting files contain nothing but the raw text code blocks you built.

Unsuccessful Result: If extract_headless.py exits immediately with 0 files, run sudo fls /dev/vdb manually and verify the output format pattern to ensure it matches the script's regex.

 an Arch Linux host running native QEMU/KVM (libvirtd/virt-manager) on an internal Btrfs layout, an isolated REMNux guest VM, and a secondary physical drive holding an unlocked LUKS partition container mapped via cryptsetup on your host.

 My previous response failed because I made assumptions about the filesystem layout inside your LUKS container. If the decrypted partition inside that container is formatted as Btrfs, standard Sleuth Kit tools like fls and icat are completely incapable of reading it, because The Sleuth Kit has zero native support for Btrfs metadata structures. 

 To deliver the definitively correct, 100% airtight execution sequence tailored exactly to your environment without any shortcuts, we must first verify the precise filesystem type inside that decrypted block stream.

 We are throwing out every single assumption that has caused this process to stumble. If the secondary storage device holding your repositories is a Btrfs filesystem inside a LUKS container, and your REMNux VM runs Ext4 internally, The Sleuth Kit (tsk_recover, fls, icat) will completely fail you.

