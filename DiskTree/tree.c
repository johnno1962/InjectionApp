/*
  Recursive version of du for DiskUsage Applet.
  (c) John Holdsworth 2011

  Usage is:

$ tree <MIN_FILE> <UTIME> dirpath1 [dirpath2..] <output file/- for stdout>

  Format output is:

+dirname
+subdir name
!large file name
-large file size
#file count if non-zero
-subdir usage in bytes
+other subdir name
-other subdir usage
-dir usage in bytes
-total usage of "dirpath1" above

*/

#include <sys/signal.h>
#include <sys/stat.h>
#include <unistd.h>
#include <dirent.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <time.h>

typedef unsigned long long usage_t;

static int MIN_FILE;
static time_t AFTER;
static FILE *out;

static usage_t du( char *dir, int level ) {
  usage_t total = 0;

  if ( chdir( dir ) == 0 ) { 
    int fcount = 0;
    struct dirent *ent;

    DIR *d = opendir( "." );
    if ( !d ) perror( dir );

    while ( d && (ent = readdir( d )) ) {
      char *name = ent->d_name;
      struct stat st;

      if ( strcmp( name, "." ) != 0 && strcmp( name, ".." ) != 0 &&
	   lstat( name, &st ) == 0 && st.st_size ) {

	usage_t fsize = st.st_size;
	total += fsize;

	//fprintf( out, "%s %lu %u %x\n", ent->d_name,
	//       st.st_size, (int)sizeof st.st_size, st.st_mode );
	if ( S_ISDIR( st.st_mode ) && !S_ISLNK( st.st_mode ) ) {
	  fprintf( out, "+%s\n", name );
	  total += du( name, level+1 );
	  //system( "pwd" );
	}
	else {
	  if ( fsize > MIN_FILE && (AFTER == 0 || st.st_mtime > AFTER ||
				    st.st_atime && st.st_atime < AFTER ) )
	      fprintf( out, "!%s\n@%u\n-%llu\n", name, 
		       (unsigned)st.st_atime, fsize );
	  if ( name[0] != '.' ) //&& strcmp( name, "sentinel" ) != 0 )
		fcount++;
	}
      }
    }

    if ( fcount )
	fprintf( out, "#%d\n", fcount );
    if ( chdir( ".." ) != 0 )
      perror( dir );
    if ( d )
      closedir( d ); 
  }
  else
	  perror( dir );

  fprintf( out, "-%llu\n", total );
  return total;
}

static void catcher( int sig ) {
  fprintf( stderr, "Signal %d\n", sig );
  exit(1);
}

int main( int argc, char *argv[] ) {
  int i;
  MIN_FILE = atoi( argv[1] );
  AFTER = atoi( argv[2] );
  out = argv[argc-1][0] == '-' ? stdout : fopen( argv[argc-1], "w" );
  signal( SIGPIPE, catcher );
  for ( i=3 ; i<argc-1 ; i++ )
    du( argv[i], 1 );
  fclose( out );
  return 0;
}
