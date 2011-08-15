#!/sbin/runscript
# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v3

# Need dependancies is not mandatory if and only if lib64 and usr are mounted in a initramfs, otherwise 
# you might run into big trouble for two reasons: rc uses a tmpfs mounted on /lib64/rc/init.d to store
# the state of services and many services need binaries/libraries from usr in the boot up. Actually, without 
# an initramfs you could get aufs2+squashfs working without an issue if you ensure: usr and lib64 get mounted 
# as earlier as possible with/without localmount help. This initservice will do the trick putting usr and lib64 
# first in the config file. Additionaly, you could disable rc_parallel and add more services in the `before' line if need be.

description="Mounts squashed directory [according to... /etc/fstab if you want to]."

depend() {
        need fsck localmount
        use lvm modules mtab
        after lvm modules
	before consolefont bootmisc acpid keymaps
        keyword -jail -openvz -prefix -vserver -lxc
}

start() {
	einfo "mounting system disk-squashed dirs."
	for DIR in $(echo "$SSQFSD"|tr ':' ' '); do sqfsd_mount "$SQFSDIR" "$DIR"; done
        einfo "mounting local disk-squashed dirs."
        for DIR in $(echo "$LSQFSD"|tr ':' ' '); do sqfsd_mount "$SQFSDIR" "$DIR"; done
}

stop() {
	einfo "umounting local disk-squashed dirs."
	for DIR in $(echo "$LSQFSD"|tr ':' ' '); do sqfsd_umount "$SQFSDIR" "$DIR"; done
        einfo "remounting in ro mode sys squashed dirs."
        for DIR in $(echo "$SSQFSD"|tr ':' ' '); do 
		if [ "$DIR" = "usr" ]; then sqfsd_remountro "$SQFSDIR" "$DIR"
		elif [ "$DIR" != "lib64" ]; then sqfsd_umount "$SQFSDIR" "$DIR"
		fi
	done
}

sqfsd_mount() {
	if [ -n "$(mount -t aufs|grep /${2})" ]; then einfo "${2} aufs branch already mounted"
	else	
		if [ -n "$(mount -t squashfs|grep ${1}/${2}/ro)" ]; then einfo "${1}/${2}/ro already mounted."
		else	ebegin "mounting squashed ${2}.sfs image"
			mount -t squashfs ${1}/${2}.sfs ${1}/${2}/ro -o nodev,loop,ro &>/dev/null
       			eend "$?" "mount squashed ${2}.sfs image failed."
		fi
		ebegin "mounting squashed ${2} aufs branch"
		mount -t aufs ${2} /${2} -o nodev,udba=notify,reval,br:${1}/${2}/rw:${1}/${2}/ro &>/dev/null
		eend "$?" "mount ${2} aufs branch failed."
	fi
}

sqfsd_umount() {
        ebegin "umounting squashed ${2} aufs branch"
	umount -lt aufs /${2} -O no_netdev &>/dev/null
	eend "$?" "umount squashed ${2} aufs branch failed."
	ebegin "umounting squashed ${2}.sfs image"
	umount -lt squashfs ${1}/${2}/ro -O no_netdev &>/dev/null
	eend "$?" "umount squashed ${2}.sfs image failed."
}

sqfsd_remountro() {
	ebegin "mounting in ro imode ${2} aufs branch"
	mount -o remount,ro /${2} &>/dev/null
	eend "$?" "failed to mount ${2} aufs branch in ro mode."
}

# vim:ts=4 
