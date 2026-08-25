# 1. Enforce the Absolute System-Wide Git Hook Block
sudo git config --system core.hooksPath /dev/null

# 2. Enforce the Global User Git Hook Block
git config --global core.hooksPath /dev/null

# 3. Hard-Lock the Global Git Profile Under Root Ownership
# This blocks any user-space agent or tool call from writing overrides to the file
sudo chown root:root ~/.gitconfig
sudo chmod 644 ~/.gitconfig

# 4. Verify the Active Precedence Table Maps Natively to the Black Hole
git config --get core.hooksPath
