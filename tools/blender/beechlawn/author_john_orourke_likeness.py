"""Compatibility entry point for the current revisioned head authoring pipeline."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from author_four_head_finish import main

if __name__ == '__main__':
    extra = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    sys.argv = [sys.argv[0], '--', '--apply', '--player', 'john_orourke', *extra]
    main()
