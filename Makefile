# .PHONY is a special target that tells make that the listed targets are not
# actual files, but rather just labels for commands
.PHONY: all

all:
	nvim --headless -c "PlenaryBustedFile test/zellij_spec.lua"
