#!/bin/bash

BSIZE=131072
COMP=gzip
EXCL=$3
EXT=$2
sqfsd="$(echo $1|tr ':' ' ')"
sqfsdir="/sqfsd"
FSTAB=n
if [ -n "$EXCL" ]; then EXCL="-e $(echo $3|tr ':' ' ')"; fi

die() {
	echo "* $1"
	exit 1
}

for dir in $sqfsd
do
	echo ">>> [re]building squashed $dir..."
	mkdir -p "$sqfsdir/$dir"/{ro,rw} || die "failed to create $dir/{ro,rw} dirs."
	mksquashfs /$dir $sqfsdir/$dir.tmp.sfs -b $BSIZE -comp $COMP $EXCL >/dev/null || \
		die "failed to build $dir.sfs img."
	if [ "$dir" = "lib64" ]; then # move rc-svcdir and cachedir.
		mkdir -p /var/{lib/init.d,cache/splash}
		mount --move "/$dir/splash/cache" /var/cache/splash &>/dev/null || die "fled to move cachedir."
		mount --move "/$dir/rc/init.d" /var/lib/init.d &>/dev/null || die "failed to move rc-svcdir."
	fi
	[ -n "$(mount -t aufs|grep -w $dir)" ] && { 
		umount -l /$dir &>/dev/null || die "failed to umount $dir aufs branch."
		}
	[ -n "$(mount -t squashfs|grep $sqfsdir/$dir/ro)" ] && { 
		umount -l $sqfsdir/$dir/ro &>/dev/null || die "failed to umount sfs img."
		}
	rm -rf "$sqfsdir/$dir"/rw/* || die "failed to clean up $sqfdir/$dir/rw."
	[ -e $sqfsdir/$dir.sfs ] && rm -f $sqfsdir/$dir.sfs 
	mv $sqfsdir/$dir.tmp.sfs $sqfsdir/$dir.sfs || die "failed to move $dir.tmp.sfs img."
	if [ "$FSTAB" = "y" ]; then
		echo "$sqfsdir/$dir.sfs $sqfsdir/$dir/ro squashfs nodev,loop,ro 0 0" >>/etc/fstab || die "..."
		echo "$dir /$dir aufs nodev,udba=reval,br:$sqfsdir/$dir/rw:$sqfsdir/$dir/ro 0 0" >>/etc/fstab || die "..."
	fi
	mount -t squashfs $sqfsdir/$dir.sfs $sqfsdir/$dir/ro -o nodev,loop,ro &>/dev/null || \
		die "failed to mount $dir.sfs img."
	if [ -n "$EXT" ]; then # now you can up[date] or rm squashed dir.
		case $EXT in
			rm) rm -rf /$dir/*;;
			up) cp -aru "$sqfsdir/$dir"/ro/* /$dir;;
			*) echo "* nothing to do, usage is [up|rm].";;
		esac
	fi
	mount -t aufs $dir /$dir -o nodev,udba=reval,br:$sqfsdir/$dir/rw:$sqfsdir/$dir/ro &>/dev/null || \
		die "failed to mount $dir aufs branch."
	if [ "$dir" = "lib64" ]; then # move back rc-svcdir and cachedir.
		mount --move /var/cache/splash "/$dir/splash/cache" &>/dev/nul || die "failed to move back cachedir."
		mount --move /var/lib/init.d "/$dir/rc/init.d" &>/dev/null || die "failed to move back rc-svcdir."
	fi
	echo ">>> ...squashed $dir sucessfully [re]build."
done

unset BSIZE
unset COMP
unset EXCL
unset EXT
unset sqfsd
unset sqfsdir
unset FSTAB

