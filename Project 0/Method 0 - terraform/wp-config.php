<?php
/**
 * The base configuration for WordPress
 *
 * The wp-config.php creation script uses this file during the installation.
 * You don't have to use the web site, you can copy this file to "wp-config.php"
 * and fill in the values.
 *
 * This file contains the following configurations:
 *
 * * Database settings
 * * Secret keys
 * * Database table prefix
 * * ABSPATH
 *
 * @link https://wordpress.org/documentation/article/editing-wp-config-php/
 *
 * @package WordPress
 */

// ** Database settings - You can get this info from your web host ** //
/** The name of the database for WordPress */
define( 'DB_NAME', 'wordpress' );

/** Database username */
define( 'DB_USER', 'wordpress' );

/** Database password */
define( 'DB_PASSWORD', 'PMEa7[!+mDm4d5mv' );

/** Database hostname */
define( 'DB_HOST', 'wordpress.cdutynjltmk3.us-east-1.rds.amazonaws.com' );

/** Database charset to use in creating database tables. */
define( 'DB_CHARSET', 'utf8' );

/** The database collate type. Don't change this if in doubt. */
define( 'DB_COLLATE', '' );

/**#@+
 * Authentication unique keys and salts.
 *
 * Change these to different unique phrases! You can generate these using
 * the {@link https://api.wordpress.org/secret-key/1.1/salt/ WordPress.org secret-key service}.
 *
 * You can change these at any point in time to invalidate all existing cookies.
 * This will force all users to have to log in again.
 *
 * @since 2.6.0
 */


define('AUTH_KEY',         ';oLX*[:Ci&(i-0_;+E^kM=|:Uwa{:o/3u)t-NXU6J,jfi[Yu#yV{paJ|Hu+mJ$/j');
define('SECURE_AUTH_KEY',  '(I9< $4D5,Ga>DrDL>YFCB:0bHcdXA[KQ?}<XuE!*u|;`h-F$]%Jl*~w.lSMnPa~');
define('LOGGED_IN_KEY',    'c;JL*^+lKI,sQCP]Y|GSSPufc jzTr%;zODzykI6[(-t(?ujax_W(x6(7Vp_@+~+');
define('NONCE_KEY',        'E3dd$$*X&c]G)?$#+l|A7aFGWwk|3-Xmr;+.80r+h+fe~Jbl!H/8:bf(Xe;+}--a');
define('AUTH_SALT',        '<+6ZoVl6P,m7%5T1Hy|_e#)R<Af%y+D$beIHjlGM,@-pJ@OJb%h.-&dI`o|`WehP');
define('SECURE_AUTH_SALT', '-r{9G4eSzk*[k7l8Y^9mB14y/qI,grz!r,p6JBpf2+L+|j2E?=P|<o#aOv#od [6');
define('LOGGED_IN_SALT',   '-pM{Nyta+$?6,52N%4UF&]2YnhA8{9>o{!14hE8qk=nVAv83|lJ>)vc(jN8cK-GC');
define('NONCE_SALT',       '~cTvZNCa*X9p-LOFLnbJ)(Q3?foi[U;h+lt99[QEqHhQ%InPi+`Jgq1GuK};<d_T');


/**#@-*/

/**
 * WordPress database table prefix.
 *
 * You can have multiple installations in one database if you give each
 * a unique prefix. Only numbers, letters, and underscores please!
 */
$table_prefix = 'wp_';

/**
 * For developers: WordPress debugging mode.
 *
 * Change this to true to enable the display of notices during development.
 * It is strongly recommended that plugin and theme developers use WP_DEBUG
 * in their development environments.
 *
 * For information on other constants that can be used for debugging,
 * visit the documentation.
 *
 * @link https://wordpress.org/documentation/article/debugging-in-wordpress/
 */
define( 'WP_DEBUG', false );

/* Add any custom values between this line and the "stop editing" line. */



/* That's all, stop editing! Happy publishing. */

/** Absolute path to the WordPress directory. */
if ( ! defined( 'ABSPATH' ) ) {
        define( 'ABSPATH', __DIR__ . '/' );
}

/** Sets up WordPress vars and included files. */
require_once ABSPATH . 'wp-settings.php';